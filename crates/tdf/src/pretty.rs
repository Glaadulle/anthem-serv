use std::fmt::Write;

use crate::value::{Field, Value};

pub fn pretty(fields: &[Field]) -> String {
    let mut out = String::new();
    for field in fields {
        write_field(&mut out, field, 0);
    }
    out
}

fn write_field(out: &mut String, field: &Field, depth: usize) {
    let indent = "  ".repeat(depth);
    match &field.value {
        Value::Group(children) => {
            let _ = writeln!(out, "{indent}{} {{", field.tag);
            for child in children {
                write_field(out, child, depth + 1);
            }
            let _ = writeln!(out, "{indent}}}");
        }
        value => {
            let _ = writeln!(out, "{indent}{} = {}", field.tag, inline(value));
        }
    }
}

fn inline(value: &Value) -> String {
    match value {
        Value::Integer(n) => n.to_string(),
        Value::String(text) => format!("{text:?}"),
        Value::Blob(bytes) => format!("blob[{}]", bytes.len()),
        Value::Group(fields) => format!(
            "{{ {} }}",
            fields
                .iter()
                .map(|f| format!("{} = {}", f.tag, inline(&f.value)))
                .collect::<Vec<_>>()
                .join(", ")
        ),
        Value::List(_, items) => format!(
            "[{}]",
            items.iter().map(inline).collect::<Vec<_>>().join(", ")
        ),
        Value::Map(_, _, entries) => format!(
            "{{{}}}",
            entries
                .iter()
                .map(|(k, v)| format!("{}: {}", inline(k), inline(v)))
                .collect::<Vec<_>>()
                .join(", ")
        ),
        Value::Union(key, Some(member)) => {
            format!("union({key}) {} = {}", member.tag, inline(&member.value))
        }
        Value::Union(_, None) => "union(non défini)".into(),
        Value::IntegerList(numbers) => format!("{numbers:?}"),
        Value::ObjectType { component, kind } => format!("type({component}/{kind})"),
        Value::ObjectId {
            component,
            kind,
            id,
        } => format!("objet({component}/{kind}/{id})"),
        Value::Float(f) => f.to_string(),
        Value::Generic(None) => "générique(vide)".into(),
        Value::Generic(Some(generic)) => format!("générique({})", inline(&generic.value)),
    }
}
