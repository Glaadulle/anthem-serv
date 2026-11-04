use std::time::{SystemTime, UNIX_EPOCH};

use fire2::Frame;
use tdf::{Field, Tag, Type, Value};

use crate::{Context, components::user_sessions};

pub const COMPONENT: u16 = 0x0001;

const LOGIN: u16 = 0x000A;
const LIST_ENTITLEMENTS: u16 = 0x001D;
const GET_USER_ACCESS_TOKEN: u16 = 0x0046;
const ACCESS_TOKEN_CLIENT_ID: &str = "Dylan";
const PLATFORM_PC: u64 = 4;
const PLAYER_MAIL: &str = "joueur@localhost";
const ENTITLEMENT_GROUPS: [&str; 2] = ["Anthem1PC", "Anthem1GEN"];
const ENTITLEMENT_TYPE_ONLINE_ACCESS: u64 = 1;
const ENTITLEMENT_STATUS_ACTIVE: u64 = 1;
const PRODUCT_CATALOG: u64 = 2;

pub fn handle(command: u16, request: &Frame, context: &Context) -> Option<Vec<Frame>> {
    match command {
        LOGIN => Some(login(request, context)),
        GET_USER_ACCESS_TOKEN => Some(vec![
            request.reply(tdf::encode(&user_access_token(context))),
        ]),
        LIST_ENTITLEMENTS => Some(vec![
            request.reply(tdf::encode(&list_entitlements(context))),
        ]),
        _ => None,
    }
}

fn user_access_token(context: &Context) -> Vec<Field> {
    vec![
        Field::string("ATOK", &format!("jeton-serveur-{}", context.persona_id)),
        Field::string("CLID", ACCESS_TOKEN_CLIENT_ID),
    ]
}

fn list_entitlements(context: &Context) -> Vec<Field> {
    let entitlements = ENTITLEMENT_GROUPS
        .iter()
        .zip(1u64..)
        .map(|(group, id)| {
            Value::Group(vec![
                Field::string("DEVI", ""),
                Field::string("GDAY", "2019-02-22T00:00Z"),
                Field::string("GNAM", group),
                Field::int("ID", id),
                Field::int("ISCO", 0),
                Field::int("PID", context.persona_id),
                Field::string("PJID", ""),
                Field::int("PRCA", PRODUCT_CATALOG),
                Field::string("PRID", ""),
                Field::int("STAT", ENTITLEMENT_STATUS_ACTIVE),
                Field::int("STRC", 0),
                Field::string("TAG", "ONLINE_ACCESS"),
                Field::string("TDAY", ""),
                Field::int("TYPE", ENTITLEMENT_TYPE_ONLINE_ACCESS),
                Field::int("UCNT", 0),
                Field::int("VER", 0),
            ])
        })
        .collect();
    vec![Field::new(
        Tag::new("NLST"),
        Value::List(Type::Group, entitlements),
    )]
}

fn now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |elapsed| elapsed.as_secs())
}

fn login(request: &Frame, context: &Context) -> Vec<Frame> {
    let session = vec![
        Field::int("1CON", 0),
        Field::int("BUID", context.persona_id),
        Field::int("FRST", 0),
        Field::string("KEY", "0"),
        Field::int("LLOG", now()),
        Field::string("MAIL", PLAYER_MAIL),
        Field::group(
            "PDTL",
            vec![
                Field::string("DSNM", &context.player_name),
                Field::int("LAST", 0),
                Field::int("PID", context.persona_id),
                Field::int("PLAT", PLATFORM_PC),
                Field::int("STAS", 0),
                Field::int("XREF", context.persona_id),
            ],
        ),
        Field::int("UID", context.persona_id),
    ];
    let reply = vec![
        Field::int("CNTX", 0),
        Field::int("ERRC", 0),
        Field::string("SKEY", "0"),
        Field::int("ANON", 0),
        Field::int("NTOS", 0),
        Field::group("SESS", session),
        Field::int("SPAM", 0),
        Field::int("UNDR", 0),
    ];
    vec![
        Frame::notification(
            user_sessions::COMPONENT,
            user_sessions::NOTIFY_HARDWARE_FLAGS,
            tdf::encode(&hardware_flags(context)),
        ),
        request.reply(tdf::encode(&reply)),
    ]
}

fn hardware_flags(context: &Context) -> Vec<Field> {
    let login_time = now();
    vec![
        Field::int("1CON", 0),
        Field::int("ALOC", 0),
        Field::int("BUID", context.persona_id),
        Field::new(Tag::new("CGID"), user_sessions::session_object_id(context)),
        Field::string("DSNM", &context.player_name),
        Field::int("FRST", 0),
        Field::string("KEY", "0"),
        Field::int("LAST", login_time),
        Field::int("LLOG", login_time),
        Field::string("MAIL", PLAYER_MAIL),
        Field::string("NASP", "cem_ea_id"),
        Field::int("PID", context.persona_id),
        Field::int("PLAT", PLATFORM_PC),
        Field::int("UID", context.persona_id),
        Field::int("USTP", 0),
        Field::int("XREF", context.persona_id),
    ]
}
