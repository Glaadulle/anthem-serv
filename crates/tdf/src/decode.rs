use crate::{
    tag::Tag,
    value::{Field, Generic, Type, Value},
};

const GROUP_BASE_MARKER: u8 = 0x02;

#[derive(Debug, PartialEq, Eq)]
pub enum DecodeError {
    Truncated,
    UnknownType(u8),
    InvalidString,
    VarIntOverflow,
}

pub fn decode(bytes: &[u8]) -> Result<Vec<Field>, DecodeError> {
    let mut reader = Reader { bytes, cursor: 0 };
    let mut fields = Vec::new();
    while reader.cursor < bytes.len() {
        fields.push(reader.field()?);
    }
    Ok(fields)
}

struct Reader<'a> {
    bytes: &'a [u8],
    cursor: usize,
}

impl Reader<'_> {
    fn take(&mut self, count: usize) -> Result<&[u8], DecodeError> {
        let end = self
            .cursor
            .checked_add(count)
            .ok_or(DecodeError::Truncated)?;
        let slice = self
            .bytes
            .get(self.cursor..end)
            .ok_or(DecodeError::Truncated)?;
        self.cursor = end;
        Ok(slice)
    }

    fn byte(&mut self) -> Result<u8, DecodeError> {
        Ok(self.take(1)?[0])
    }

    fn peek(&self) -> Result<u8, DecodeError> {
        self.bytes
            .get(self.cursor)
            .copied()
            .ok_or(DecodeError::Truncated)
    }

    fn kind(&mut self) -> Result<Type, DecodeError> {
        let byte = self.byte()?;
        Type::from_byte(byte).ok_or(DecodeError::UnknownType(byte))
    }

    fn varint(&mut self) -> Result<u64, DecodeError> {
        let mut byte = self.byte()?;
        let negative = byte & 0x40 != 0;
        let mut result = (byte & 0x3F) as u64;
        let mut shift = 6;
        while byte & 0x80 != 0 {
            byte = self.byte()?;
            let chunk = ((byte & 0x7F) as u64)
                .checked_shl(shift)
                .ok_or(DecodeError::VarIntOverflow)?;
            result |= chunk;
            shift += 7;
        }
        Ok(if negative {
            (result as i64).wrapping_neg() as u64
        } else {
            result
        })
    }

    fn length(&mut self) -> Result<usize, DecodeError> {
        usize::try_from(self.varint()?).map_err(|_| DecodeError::Truncated)
    }

    fn field(&mut self) -> Result<Field, DecodeError> {
        let tag = Tag::from_wire(self.take(3)?.try_into().expect("3 octets"));
        let kind = self.kind()?;
        Ok(Field::new(tag, self.value(kind)?))
    }

    fn value(&mut self, kind: Type) -> Result<Value, DecodeError> {
        Ok(match kind {
            Type::Integer => Value::Integer(self.varint()?),
            Type::String => {
                let len = self.length()?;
                let raw = self.take(len)?;
                let text = raw.strip_suffix(&[0]).unwrap_or(raw);
                Value::String(
                    String::from_utf8(text.to_vec()).map_err(|_| DecodeError::InvalidString)?,
                )
            }
            Type::Blob => {
                let len = self.length()?;
                Value::Blob(self.take(len)?.to_vec())
            }
            Type::Group => {
                let mut fields = Vec::new();
                if self.peek()? == GROUP_BASE_MARKER {
                    self.cursor += 1;
                }
                while self.peek()? != 0 {
                    fields.push(self.field()?);
                }
                self.cursor += 1;
                Value::Group(fields)
            }
            Type::List => {
                let item_type = self.kind()?;
                let count = self.length()?;
                let items = (0..count)
                    .map(|_| self.value(item_type))
                    .collect::<Result<_, _>>()?;
                Value::List(item_type, items)
            }
            Type::Map => {
                let key_type = self.kind()?;
                let value_type = self.kind()?;
                let count = self.length()?;
                let entries = (0..count)
                    .map(|_| Ok((self.value(key_type)?, self.value(value_type)?)))
                    .collect::<Result<_, _>>()?;
                Value::Map(key_type, value_type, entries)
            }
            Type::Union => {
                let key = self.byte()?;
                let member = if key == Value::UNION_UNSET {
                    None
                } else {
                    Some(Box::new(self.field()?))
                };
                Value::Union(key, member)
            }
            Type::IntegerList => {
                let count = self.length()?;
                Value::IntegerList(
                    (0..count)
                        .map(|_| self.varint())
                        .collect::<Result<_, _>>()?,
                )
            }
            Type::ObjectType => Value::ObjectType {
                component: self.varint()?,
                kind: self.varint()?,
            },
            Type::ObjectId => Value::ObjectId {
                component: self.varint()?,
                kind: self.varint()?,
                id: self.varint()?,
            },
            Type::Float => Value::Float(f32::from_be_bytes(
                self.take(4)?.try_into().expect("4 octets"),
            )),
            Type::Generic => {
                if self.byte()? == 0 {
                    Value::Generic(None)
                } else {
                    let type_id = self.varint()?;
                    let flag = self.byte()?;
                    let kind = self.kind()?;
                    let value = Box::new(self.value(kind)?);
                    self.byte()?;
                    Value::Generic(Some(Generic {
                        type_id,
                        flag,
                        value,
                    }))
                }
            }
        })
    }
}
