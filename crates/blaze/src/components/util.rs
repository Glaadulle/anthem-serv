use std::time::{SystemTime, UNIX_EPOCH};

use fire2::Frame;

use crate::{Context, components::user_sessions};
use tdf::{Field, Value};

pub const COMPONENT: u16 = 0x0009;

const FETCH_CLIENT_CONFIG: u16 = 0x0001;
const PING: u16 = 0x0002;
const UNKNOWN_0005: u16 = 0x0005;
const PRE_AUTH: u16 = 0x0007;
const POST_AUTH: u16 = 0x0008;
const SET_CLIENT_METRICS: u16 = 0x0016;

const SUPPORTED_COMPONENTS: [u64; 10] = [
    0x0001, 0x0004, 0x0007, 0x0009, 0x000A, 0x000B, 0x000F, 0x0019, 0x001C, 0x7802,
];

pub fn handle(command: u16, request: &Frame, context: &Context) -> Option<Vec<Frame>> {
    let reply = |fields: Vec<Field>| vec![request.reply(tdf::encode(&fields))];
    match command {
        FETCH_CLIENT_CONFIG => Some(reply(fetch_client_config(request, context))),
        PING => Some(reply(ping())),
        PRE_AUTH => Some(reply(pre_auth(context))),
        POST_AUTH => Some(post_auth(request, context)),
        SET_CLIENT_METRICS | UNKNOWN_0005 => Some(vec![request.reply(Vec::new())]),
        _ => None,
    }
}

fn post_auth(request: &Frame, context: &Context) -> Vec<Frame> {
    let attribute = vec![Field::int("FLGS", 3), Field::int("ID", context.persona_id)];
    let reply = vec![
        Field::group(
            "TELE",
            vec![
                Field::string("ADRS", ""),
                Field::int("ANON", 0),
                Field::string("DISA", ""),
                Field::int("EDCT", 0),
                Field::string("FILT", ""),
                Field::int("LOC", 0),
                Field::int("MINR", 0),
                Field::string("NOOK", ""),
                Field::int("PORT", 0),
                Field::int("SDLY", 15000),
                Field::string("SESS", ""),
                Field::string("SKEY", ""),
                Field::int("SPCT", 0),
                Field::string("STIM", "Default"),
                Field::string("SVNM", ""),
            ],
        ),
        Field::group(
            "TICK",
            vec![
                Field::string("ADRS", ""),
                Field::int("PORT", 0),
                Field::string("SKEY", ""),
            ],
        ),
        Field::group(
            "UROP",
            vec![Field::int("TMOP", 0), Field::int("UID", context.persona_id)],
        ),
    ];
    let extended_data = vec![Field::group(
        "DATA",
        user_sessions::session_data(
            context,
            tdf::Value::Union(tdf::Value::UNION_UNSET, None),
            true,
        ),
    )];
    vec![
        Frame::notification(
            user_sessions::COMPONENT,
            user_sessions::NOTIFY_EXTENDED_DATA_ATTRIBUTE,
            tdf::encode(&attribute),
        ),
        request.reply(tdf::encode(&reply)),
        Frame::notification(
            user_sessions::COMPONENT,
            user_sessions::NOTIFY_EXTENDED_DATA,
            tdf::encode(&extended_data),
        ),
    ]
}

fn requested_config_id(request: &Frame) -> Option<String> {
    tdf::decode(&request.payload)
        .ok()?
        .into_iter()
        .find(|field| field.tag.to_string() == "CFID")
        .and_then(|field| match field.value {
            Value::String(id) => Some(id),
            _ => None,
        })
}

fn fetch_client_config(request: &Frame, context: &Context) -> Vec<Field> {
    let bigs = context.bigs_url.as_str();
    let auth = format!("{bigs}/auth");
    let ebs = format!("{bigs}/ebs");
    let nucleus = format!("{bigs}/nucleus");
    let entries: Vec<(&str, &str)> = match requested_config_id(request).as_deref() {
        Some("IdentityParams") => vec![
            ("display", "console2/welcome"),
            ("redirect_uri", "http://127.0.0.1/success"),
        ],
        Some(id) if id.starts_with("AnthemMain") => vec![
            ("bigs_auth_url", &auth),
            ("bigs_default_url", bigs),
            ("bigs_ebs_url", &ebs),
            ("bigs_env_name", "prod"),
            ("eadp_product_id", ""),
            ("lcu_patch_directory", ""),
            ("lcu_patch_server", ""),
            ("nucleus_url", &nucleus),
            ("telemetry_env", "prod"),
            ("telemetry_url", ""),
            ("thor_header1", ""),
            ("thor_header2", ""),
            ("thor_url", ""),
        ],
        _ => Vec::new(),
    };
    vec![Field::string_map("CONF", &entries)]
}

fn ping() -> Vec<Field> {
    let seconds = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |elapsed| elapsed.as_secs());
    vec![Field::int("TIME", seconds)]
}

fn pre_auth(context: &Context) -> Vec<Field> {
    let nucleus = format!("{}/nucleus", context.bigs_url);
    let config = vec![
        ("associationListSkipInitialSet", "1"),
        ("autoReconnectEnabled", "0"),
        ("connIdleTimeout", "40s"),
        ("defaultRequestTimeout", "20s"),
        ("nucleusConnectTrusted", nucleus.as_str()),
        ("pingPeriod", "20s"),
        ("userManagerMaxCachedUsers", "0"),
        ("voipHeadsetUpdateRate", "1000"),
        ("voipSTTKey", ""),
        ("voipSTTProfile", "0"),
        ("voipSTTUrl", ""),
        ("voipTTSKey", ""),
        ("voipTTSProvider", "0"),
        ("voipTTSUrl", ""),
    ];
    vec![
        Field::string("ASRC", "anthem"),
        Field::int_list("CIDS", &SUPPORTED_COMPONENTS),
        Field::string("CLID", "Dylan-SERVER-PC"),
        Field::group("CONF", vec![Field::string_map("CONF", &config)]),
        Field::string("ESRC", "anthem"),
        Field::string("INST", "anthem-1-pc"),
        Field::int("MAID", 0),
        Field::int("MINR", 0),
        Field::string("NASP", "cem_ea_id"),
        Field::string("PILD", ""),
        Field::string("PLAT", "pc"),
        Field::group(
            "QOSS",
            vec![
                Field::group(
                    "BWPS",
                    vec![
                        Field::string("PSA", ""),
                        Field::int("PSP", 0),
                        Field::string("SNA", ""),
                    ],
                ),
                Field::int("LNP", 10),
                Field::new(
                    tdf::Tag::new("LTPS"),
                    tdf::Value::Map(tdf::Type::String, tdf::Type::Group, Vec::new()),
                ),
                Field::int("SVID", 0),
                Field::int("TIME", 5_000_000),
            ],
        ),
        Field::string("RSRC", "anthem"),
        Field::string("SVER", "Blaze 15.1.1.7.5"),
    ]
}
