use fire2::Frame;
use tdf::{Field, Tag, Type, Value};

use crate::Context;

pub const COMPONENT: u16 = 0x0019;

const ADD_USERS_TO_LIST: u16 = 0x0001;
const REMOVE_USERS_FROM_LIST: u16 = 0x0002;
const CLEAR_LISTS: u16 = 0x0003;
const SET_USERS_TO_LIST: u16 = 0x0004;
const GET_LIST_FOR_USER: u16 = 0x0005;
const GET_LISTS: u16 = 0x0006;
const SUBSCRIBE_TO_LISTS: u16 = 0x0007;
const UNSUBSCRIBE_FROM_LISTS: u16 = 0x0008;
const GET_MEMBER_HASH: u16 = 0x000A;
const LIST_OBJECT_TYPE: u64 = 1;
const FRIEND_LIST: &str = "friendList";
const PERSONA_NAMESPACE: &str = "cem_ea_id";

pub fn handle(command: u16, request: &Frame, context: &Context) -> Option<Vec<Frame>> {
    match command {
        GET_LISTS => Some(vec![get_lists(request, context)]),
        ADD_USERS_TO_LIST
        | REMOVE_USERS_FROM_LIST
        | CLEAR_LISTS
        | SET_USERS_TO_LIST
        | GET_LIST_FOR_USER
        | SUBSCRIBE_TO_LISTS
        | UNSUBSCRIBE_FROM_LISTS
        | GET_MEMBER_HASH => Some(vec![request.reply(Vec::new())]),
        _ => None,
    }
}

fn requested_lists(request: &Frame) -> Vec<Value> {
    tdf::decode(&request.payload)
        .unwrap_or_default()
        .into_iter()
        .find(|field| field.tag.to_string() == "ALST")
        .and_then(|field| match field.value {
            Value::List(_, items) => Some(items),
            _ => None,
        })
        .unwrap_or_default()
}

fn list_name(info: &Value) -> Option<&str> {
    let Value::Group(info) = info else {
        return None;
    };
    let Value::Group(id) = &info.iter().find(|f| f.tag.to_string() == "LID")?.value else {
        return None;
    };
    match &id.iter().find(|f| f.tag.to_string() == "LNM")?.value {
        Value::String(name) => Some(name),
        _ => None,
    }
}

/// ListInfo demandé, identifié par BOID = objet (Association, liste, rang).
fn identified(info: Value, rank: u64) -> Value {
    let Value::Group(mut fields) = info else {
        return info;
    };
    let object = Value::ObjectId {
        component: COMPONENT.into(),
        kind: LIST_OBJECT_TYPE,
        id: rank,
    };
    match fields.iter_mut().find(|f| f.tag.to_string() == "BOID") {
        Some(boid) => boid.value = object,
        None => fields.insert(0, Field::new(Tag::new("BOID"), object)),
    }
    Value::Group(fields)
}

/// ListMemberInfo {LMID: ListMemberId {USER: CoreIdentification}, TIME} de chaque autre persona connu.
fn friends(context: &Context) -> Vec<Value> {
    context
        .known_personas()
        .into_iter()
        .filter(|(id, _)| *id != context.persona_id)
        .map(|(id, name)| {
            Value::Group(vec![
                Field::group(
                    "LMID",
                    vec![Field::group(
                        "USER",
                        vec![
                            Field::int("EXID", id),
                            Field::int("ID", id),
                            Field::string("NAME", &name),
                            Field::string("NASP", PERSONA_NAMESPACE),
                        ],
                    )],
                ),
                Field::int("TIME", 0),
            ])
        })
        .collect()
}

fn get_lists(request: &Frame, context: &Context) -> Frame {
    let lists = requested_lists(request)
        .into_iter()
        .zip(1..)
        .map(|(info, rank)| {
            let members = if list_name(&info) == Some(FRIEND_LIST) {
                friends(context)
            } else {
                Vec::new()
            };
            let count = members.len() as u64;
            Value::Group(vec![
                Field::new(Tag::new("INFO"), identified(info, rank)),
                Field::new(Tag::new("MEML"), Value::List(Type::Group, members)),
                Field::int("OFRC", 0),
                Field::int("TOCT", count),
            ])
        })
        .collect();
    request.reply(tdf::encode(&[Field::new(
        Tag::new("LMAP"),
        Value::List(Type::Group, lists),
    )]))
}
