use crate::value::{Field, Type, Value};

pub fn encode(fields: &[Field]) -> Vec<u8> {
    let mut out = Vec::new();
    for field in fields {
        write_field(&mut out, field);
    }
    out
}

fn write_field(out: &mut Vec<u8>, field: &Field) {
    out.extend_from_slice(&field.tag.to_wire());
    out.push(field.value.kind() as u8);
    write_value(out, &field.value);
}

fn write_value(out: &mut Vec<u8>, value: &Value) {
    match value {
        Value::Integer(n) => write_varint(out, *n),
        Value::String(text) => {
            write_varint(out, text.len() as u64 + 1);
            out.extend_from_slice(text.as_bytes());
            out.push(0);
        }
        Value::Blob(bytes) => {
            write_varint(out, bytes.len() as u64);
            out.extend_from_slice(bytes);
        }
        Value::Group(fields) => {
            for field in fields {
                write_field(out, field);
            }
            out.push(0);
        }
        Value::List(Type::Union, items) => {
            out.push(Type::Group as u8);
            write_varint(out, items.len() as u64);
            for item in items {
                write_heat_union_element(out, item);
            }
        }
        Value::List(item_type, items) => {
            out.push(*item_type as u8);
            write_varint(out, items.len() as u64);
            for item in items {
                write_value(out, item);
            }
        }
        Value::Map(key_type, value_type, entries) => {
            out.push(*key_type as u8);
            out.push(*value_type as u8);
            write_varint(out, entries.len() as u64);
            for (key, entry) in entries {
                write_value(out, key);
                write_value(out, entry);
            }
        }
        Value::Union(key, member) => {
            out.push(*key);
            if let Some(member) = member {
                write_field(out, member);
            }
        }
        Value::IntegerList(numbers) => {
            write_varint(out, numbers.len() as u64);
            for n in numbers {
                write_varint(out, *n);
            }
        }
        Value::ObjectType { component, kind } => {
            write_varint(out, *component);
            write_varint(out, *kind);
        }
        Value::ObjectId {
            component,
            kind,
            id,
        } => {
            write_varint(out, *component);
            write_varint(out, *kind);
            write_varint(out, *id);
        }
        Value::Float(f) => out.extend_from_slice(&f.to_be_bytes()),
        Value::Generic(None) => out.push(0),
        Value::Generic(Some(generic)) => {
            out.push(1);
            write_varint(out, generic.type_id);
            out.push(generic.flag);
            out.push(generic.value.kind() as u8);
            write_value(out, &generic.value);
            out.push(0);
        }
    }
}

/// Le bit 0x40 du premier octet porte le signe ; les négatifs arrivent en complément à deux sur 64 bits.
/// Élément de liste d'unions au format « heat » de BlazeSDK : indice, champs du membre, 0, sans en-tête de membre.
fn write_heat_union_element(out: &mut Vec<u8>, item: &Value) {
    match item {
        Value::Union(key, Some(member)) => {
            out.push(*key);
            match &member.value {
                Value::Group(fields) => {
                    for field in fields {
                        write_field(out, field);
                    }
                }
                other => write_value(out, other),
            }
            out.push(0);
        }
        Value::Union(key, None) => {
            out.push(*key);
            out.push(0);
        }
        other => write_value(out, other),
    }
}

fn write_varint(out: &mut Vec<u8>, value: u64) {
    let signed = value as i64;
    let sign = if signed < 0 { 0x40 } else { 0 };
    let magnitude = signed.unsigned_abs();
    if magnitude < 0x40 {
        out.push(magnitude as u8 | sign);
        return;
    }
    out.push((magnitude & 0x3F) as u8 | sign | 0x80);
    let mut rest = magnitude >> 6;
    while rest >= 0x80 {
        out.push((rest & 0x7F) as u8 | 0x80);
        rest >>= 7;
    }
    out.push(rest as u8);
}
