use crate::tag::Tag;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum Type {
    Integer = 0x0,
    String = 0x1,
    Blob = 0x2,
    Group = 0x3,
    List = 0x4,
    Map = 0x5,
    Union = 0x6,
    IntegerList = 0x7,
    ObjectType = 0x8,
    ObjectId = 0x9,
    Float = 0xA,
    Generic = 0xC,
}

impl Type {
    pub fn from_byte(byte: u8) -> Option<Self> {
        Some(match byte {
            0x0 => Self::Integer,
            0x1 => Self::String,
            0x2 => Self::Blob,
            0x3 => Self::Group,
            0x4 => Self::List,
            0x5 => Self::Map,
            0x6 => Self::Union,
            0x7 => Self::IntegerList,
            0x8 => Self::ObjectType,
            0x9 => Self::ObjectId,
            0xA => Self::Float,
            0xC => Self::Generic,
            _ => return None,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
pub enum Value {
    Integer(u64),
    String(String),
    Blob(Vec<u8>),
    Group(Vec<Field>),
    List(Type, Vec<Value>),
    Map(Type, Type, Vec<(Value, Value)>),
    Union(u8, Option<Box<Field>>),
    IntegerList(Vec<u64>),
    ObjectType { component: u64, kind: u64 },
    ObjectId { component: u64, kind: u64, id: u64 },
    Float(f32),
    Generic(Option<Generic>),
}

impl Value {
    pub const UNION_UNSET: u8 = 0x7F;

    pub fn kind(&self) -> Type {
        match self {
            Self::Integer(_) => Type::Integer,
            Self::String(_) => Type::String,
            Self::Blob(_) => Type::Blob,
            Self::Group(_) => Type::Group,
            Self::List(..) => Type::List,
            Self::Map(..) => Type::Map,
            Self::Union(..) => Type::Union,
            Self::IntegerList(_) => Type::IntegerList,
            Self::ObjectType { .. } => Type::ObjectType,
            Self::ObjectId { .. } => Type::ObjectId,
            Self::Float(_) => Type::Float,
            Self::Generic(_) => Type::Generic,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct Generic {
    pub type_id: u64,
    pub flag: u8,
    pub value: Box<Value>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Field {
    pub tag: Tag,
    pub value: Value,
}

impl Field {
    pub fn new(tag: Tag, value: Value) -> Self {
        Self { tag, value }
    }

    pub fn int(tag: &str, value: u64) -> Self {
        Self::new(Tag::new(tag), Value::Integer(value))
    }

    pub fn string(tag: &str, value: &str) -> Self {
        Self::new(Tag::new(tag), Value::String(value.to_owned()))
    }

    pub fn group(tag: &str, fields: Vec<Field>) -> Self {
        Self::new(Tag::new(tag), Value::Group(fields))
    }

    pub fn int_list(tag: &str, values: &[u64]) -> Self {
        Self::new(
            Tag::new(tag),
            Value::List(
                Type::Integer,
                values.iter().map(|&v| Value::Integer(v)).collect(),
            ),
        )
    }

    pub fn string_map(tag: &str, entries: &[(&str, &str)]) -> Self {
        let entries = entries
            .iter()
            .map(|(k, v)| {
                (
                    Value::String((*k).to_owned()),
                    Value::String((*v).to_owned()),
                )
            })
            .collect();
        Self::new(
            Tag::new(tag),
            Value::Map(Type::String, Type::String, entries),
        )
    }
}
