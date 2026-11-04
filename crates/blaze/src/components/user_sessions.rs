use fire2::Frame;
use tdf::{Field, Tag, Type, Value};

use crate::Context;

pub const COMPONENT: u16 = 0x7802;

pub const NOTIFY_SESSION_KEY: u16 = 0x0001;
pub const NOTIFY_EXTENDED_DATA: u16 = 0x0002;
pub const NOTIFY_EXTENDED_DATA_ATTRIBUTE: u16 = 0x0005;
pub const NOTIFY_HARDWARE_FLAGS: u16 = 0x0008;

const UPDATE_HARDWARE_FLAGS: u16 = 0x0008;
const LOOKUP_USERS: u16 = 0x000d;
const LOOKUP_TYPE_BLAZE_ID: u64 = 0;
const UPDATE_NETWORK_INFO: u16 = 0x0014;
const SESSION_OBJECT_TYPE: u64 = 2;

pub fn handle(command: u16, request: &Frame, context: &Context) -> Option<Vec<Frame>> {
    match command {
        UPDATE_HARDWARE_FLAGS => Some(vec![request.reply(Vec::new())]),
        LOOKUP_USERS => Some(vec![lookup_users(request, context)]),
        UPDATE_NETWORK_INFO => Some(update_network_info(request, context)),
        _ => None,
    }
}

pub fn session_object_id(context: &Context) -> Value {
    Value::ObjectId {
        component: COMPONENT as u64,
        kind: SESSION_OBJECT_TYPE,
        id: context.persona_id,
    }
}

fn client_address(request: &Frame) -> Option<Value> {
    tdf::decode(&request.payload)
        .ok()?
        .into_iter()
        .find(|field| field.tag.to_string() == "INFO")
        .and_then(|info| match info.value {
            Value::Group(fields) => fields
                .into_iter()
                .find(|field| field.tag.to_string() == "ADDR"),
            _ => None,
        })
        .map(|addr| addr.value)
}

fn update_network_info(request: &Frame, context: &Context) -> Vec<Frame> {
    let address = client_address(request).unwrap_or(Value::Union(Value::UNION_UNSET, None));
    let notification = vec![
        Field::group("DATA", session_data(context, address, false)),
        Field::int("SUBS", 1),
        Field::int("USID", context.persona_id),
    ];
    vec![
        request.reply(Vec::new()),
        Frame::notification(COMPONENT, NOTIFY_SESSION_KEY, tdf::encode(&notification)),
    ]
}

pub fn session_data(context: &Context, address: Value, with_user: bool) -> Vec<Field> {
    let mut data = vec![
        Field::new(Tag::new("ADDR"), address),
        Field::string("BPS", ""),
        Field::string("CTY", ""),
        Field::new(Tag::new("CVAR"), Value::IntegerList(Vec::new())),
        Field::new(
            Tag::new("DMAP"),
            Value::Map(Type::Integer, Type::Integer, Vec::new()),
        ),
        Field::int("HWFG", 0),
        Field::string("ISP", ""),
        Field::group(
            "QDAT",
            vec![
                Field::int("BWHR", 0),
                Field::int("DBPS", 0),
                Field::int("NAHR", 0),
                Field::int("NATT", 0),
                Field::int("UBPS", 0),
            ],
        ),
        Field::string("TZ", ""),
        Field::int("UATT", 0),
        Field::new(
            Tag::new("ULST"),
            if with_user {
                Value::IntegerList(vec![
                    COMPONENT as u64,
                    SESSION_OBJECT_TYPE,
                    context.persona_id,
                ])
            } else {
                session_object_id(context)
            },
        ),
    ];
    if with_user {
        data.push(Field::group("USER", user_identification(context)));
    }
    data
}

fn user_identification(context: &Context) -> Vec<Field> {
    vec![
        Field::int("AID", context.persona_id),
        Field::int("ALOC", 0),
        Field::new(Tag::new("EXBB"), Value::Blob(Vec::new())),
        Field::int("EXID", context.persona_id),
        Field::int("ID", context.persona_id),
        Field::string("NAME", &context.player_name),
        Field::string("NASP", "cem_ea_id"),
        Field::int("ORIG", context.persona_id),
        Field::int("PIDI", 0),
    ]
}

/// UserDataResponse {ULST: [UserData {EDAT, USER}]} des personas connus parmi les UserIdentification demandés (BLAZE_ID).
fn lookup_users(request: &Frame, context: &Context) -> Frame {
    let fields = tdf::decode(&request.payload).unwrap_or_default();
    let field = |tag: &str| {
        fields
            .iter()
            .find(|f| f.tag.to_string() == tag)
            .map(|f| &f.value)
    };
    let by_blaze_id = matches!(
        field("LTYP"),
        None | Some(Value::Integer(LOOKUP_TYPE_BLAZE_ID))
    );
    let wanted = match field("ULST") {
        Some(Value::List(_, users)) if by_blaze_id => users.as_slice(),
        _ => &[],
    };
    let users = wanted
        .iter()
        .filter_map(|user| match user {
            Value::Group(user) => user.iter().find(|f| f.tag.to_string() == "ID"),
            _ => None,
        })
        .filter_map(|id| match id.value {
            Value::Integer(id) => context
                .persona_name(id)
                .map(|name| user_data(&context.with_identity(id, &name))),
            _ => None,
        })
        .collect();
    request.reply(tdf::encode(&[Field::new(
        Tag::new("ULST"),
        Value::List(Type::Group, users),
    )]))
}

fn user_data(context: &Context) -> Value {
    Value::Group(vec![
        Field::group(
            "EDAT",
            extended_data(context, Value::Union(Value::UNION_UNSET, None)),
        ),
        Field::group("USER", user_identification(context)),
    ])
}

fn extended_data(context: &Context, address: Value) -> Vec<Field> {
    let mut data = session_data(context, address, true);
    data.retain(|field| field.tag.to_string() != "USER");
    data
}

/// NotifyUserAdded {DATA: UserSessionExtendedData, USER: UserIdentification} d'un autre joueur (data/tdf_blaze.txt).
pub fn user_added(context: &Context, address: Value) -> Frame {
    let added = vec![
        Field::group("DATA", extended_data(context, address)),
        Field::group("USER", user_identification(context)),
    ];
    Frame::notification(COMPONENT, NOTIFY_EXTENDED_DATA, tdf::encode(&added))
}
