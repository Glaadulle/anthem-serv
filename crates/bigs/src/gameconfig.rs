use axum::{
    Json,
    body::Bytes,
    extract::{Path, State},
};
use serde_json::{Value, json};

use crate::Context;

const ANY_EXO_TYPE: i32 = -1;
const ANY_DIFFICULTY: u32 = 0;

fn empty_breakdown() -> Value {
    json!({ "packId": "", "resultTickets": [], "resultCurrencies": [] })
}

pub async fn quest_reward(Path(quest): Path<u32>) -> Json<Value> {
    Json(json!({
        "reward": {
            "questId": quest,
            "rewards": [{
                "minLevel": 0,
                "possibleRewards": empty_breakdown(),
                "possibleRepeatRewards": empty_breakdown(),
                "exoType": ANY_EXO_TYPE,
                "difficulty": ANY_DIFFICULTY,
            }],
            "recurringSchedule": [],
            "registeredDefinitionId": 0,
            "startTime": 0,
            "endTime": 0,
        },
        "signature": "",
    }))
}

fn paged(list: &str) -> Json<Value> {
    Json(json!({ list: [], "signature": "", "totalCount": 0 }))
}

pub async fn config() -> Json<Value> {
    Json(json!({ "bools": [], "floats": [], "ints": [], "strings": [] }))
}

const LOOT_RARITIES: std::ops::RangeInclusive<i32> = 0..=6;

/// Table par défaut sans Tags, un ticket par rareté : sans elle, le butin au sol ne se ramasse pas.
pub async fn loot_tables() -> Json<Value> {
    let mappings: Vec<Value> = LOOT_RARITIES
        .map(|rarity| json!({ "rarityType": rarity, "ticket": format!("bigs-butin-rarete-{rarity}") }))
        .collect();
    let tables = [json!({
        "name": "bigs-butin",
        "id": "bigs-butin",
        "tags": [],
        "lootType": 0,
        "ticketMappings": mappings,
        "startTime": 0,
        "endTime": 0,
        "minCL": 0,
        "recurringSchedule": [],
    })];
    Json(json!({ "tables": tables, "signature": "", "totalCount": tables.len() }))
}

pub async fn recipes() -> Json<Value> {
    paged("recipes")
}

pub async fn infusions() -> Json<Value> {
    paged("infusions")
}

pub async fn salvage() -> Json<Value> {
    let items = crate::gear::salvage_table();
    Json(json!({ "items": items, "signature": "", "totalCount": items.len() }))
}

pub async fn tuning(State(context): State<Context>) -> Json<Value> {
    let values = context
        .weapon_damage
        .lock()
        .expect("table des dégâts")
        .tuning_values();
    Json(json!({ "totalCount": values.len(), "values": values, "signature": "" }))
}

pub async fn editor_damage(State(context): State<Context>) -> Json<Value> {
    Json(Value::Array(
        context
            .weapon_damage
            .lock()
            .expect("table des dégâts")
            .editor_rows(),
    ))
}

pub async fn set_editor_damage(State(context): State<Context>, body: Bytes) -> Json<Value> {
    let changes: Vec<Value> = serde_json::from_slice(&body).unwrap_or_default();
    context
        .weapon_damage
        .lock()
        .expect("table des dégâts")
        .adjust(&changes);
    editor_damage(State(context)).await
}

pub async fn mutators() -> Json<Value> {
    Json(json!({ "activeMutators": [], "signature": "" }))
}

pub async fn faction_rewards() -> Json<Value> {
    Json(json!({ "factionRewards": [], "factionTags": [], "rewardTags": [] }))
}

pub async fn weather() -> Json<Value> {
    Json(json!({
        "weatherState": {
            "weatherState": 0,
            "humidity": 0.0,
            "temperature": 0.0,
            "cloudiness": 0.0,
            "windDirection": 0.0,
            "windSpeed": 0.0,
        }
    }))
}

pub async fn weather_events() -> Json<Value> {
    Json(json!({ "weatherEvents": [] }))
}

pub async fn initial_weather_states() -> Json<Value> {
    Json(json!({ "initialWeatherStates": [] }))
}

pub async fn live_strings(Path(language): Path<String>) -> Json<Value> {
    Json(json!({ "languageTag": language, "liveStrings": [] }))
}

pub async fn skins() -> Json<Value> {
    Json(json!({ "skins": [] }))
}

pub async fn ignored_players() -> Json<Value> {
    Json(json!({ "ignoreIds": [] }))
}

pub async fn favorite_players() -> Json<Value> {
    Json(json!({ "favoriteIds": [] }))
}

pub async fn inventory_startup() -> Json<Value> {
    Json(json!({}))
}

pub async fn play_time() -> Json<Value> {
    Json(json!({ "totalPlayTime": 0 }))
}
