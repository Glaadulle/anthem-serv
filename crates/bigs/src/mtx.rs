use axum::{
    Json,
    body::Bytes,
    extract::{RawQuery, State},
};
use serde_json::{Value, json};

use crate::Context;

const JAVELIN_TOKEN: &str = "CurrencyType_Javelin";
const STARTING_JAVELIN_TOKENS: i32 = 1;
const EXO_OFFER_TYPE: u32 = 2;

struct PurchasableExo {
    name: &'static str,
    exo_type: i32,
    unlock_guid: &'static str,
}

pub struct ExoUnlock {
    pub name: String,
    pub guid: &'static str,
}

const STARTING_EXO_NAME: &str = "Lancer";
const STARTING_EXO_UNLOCK_GUID: &str = "e138c1a9-9b28-42ff-b041-650726d43492";

const PURCHASABLE_EXOS: [PurchasableExo; 3] = [
    PurchasableExo {
        name: "Colossus",
        exo_type: 1,
        unlock_guid: "9c65b42a-6bf9-4e0d-b4e2-726ce0c46bde",
    },
    PurchasableExo {
        name: "Storm",
        exo_type: 2,
        unlock_guid: "a6a19dba-d7c3-4d64-b476-8bc2d6c409d5",
    },
    PurchasableExo {
        name: "Nova",
        exo_type: 3,
        unlock_guid: "3c64ce11-d611-4668-8c28-ffb3fd182c04",
    },
];

impl PurchasableExo {
    fn offer_id(&self) -> String {
        format!("Offer_Exo_{}", self.name)
    }

    fn unlock_ids(&self) -> Vec<String> {
        vec![self.unlock_guid.to_owned()]
    }
}

fn query_value(query: &Option<String>, key: &str) -> Option<String> {
    query
        .as_deref()
        .and_then(|query| crate::form_value(query.as_bytes(), key))
}

fn bought_exos(context: &Context) -> Vec<&'static PurchasableExo> {
    let bought = context
        .state
        .lock()
        .expect("fichier d'état")
        .bought_offers();
    PURCHASABLE_EXOS
        .iter()
        .filter(|exo| bought.contains(&exo.offer_id()))
        .collect()
}

pub fn bought_exo_types(context: &Context) -> Vec<i32> {
    bought_exos(context)
        .iter()
        .map(|exo| exo.exo_type)
        .collect()
}

fn unlock_name(exo_name: &str) -> String {
    format!("EXOType_{exo_name}_unlocked")
}

pub fn exo_unlocks(context: &Context) -> Vec<ExoUnlock> {
    let starting = ExoUnlock {
        name: unlock_name(STARTING_EXO_NAME),
        guid: STARTING_EXO_UNLOCK_GUID,
    };
    let bought = bought_exos(context).into_iter().map(|exo| ExoUnlock {
        name: unlock_name(exo.name),
        guid: exo.unlock_guid,
    });
    std::iter::once(starting).chain(bought).collect()
}

fn remaining_javelin_tokens(context: &Context) -> i32 {
    let spent = i32::try_from(bought_exos(context).len()).unwrap_or(STARTING_JAVELIN_TOKENS);
    (STARTING_JAVELIN_TOKENS - spent).max(0)
}

fn javelin_tokens(amount: i32) -> Value {
    json!({ "currencyId": JAVELIN_TOKEN, "amount": amount, "originalAmount": STARTING_JAVELIN_TOKENS })
}

pub async fn balances(State(context): State<Context>, RawQuery(query): RawQuery) -> Json<Value> {
    let currency = query_value(&query, "currencyAlias").unwrap_or_default();
    let balance = if currency == JAVELIN_TOKEN {
        remaining_javelin_tokens(&context)
    } else {
        0
    };
    Json(json!({ "balances": [{
        "balanceId": currency,
        "currencyAlias": currency,
        "balance": balance,
        "updatedAt": "",
    }] }))
}

pub async fn offers(State(context): State<Context>, RawQuery(query): RawQuery) -> Json<Value> {
    if query_value(&query, "offerTypes").and_then(|value| value.parse().ok())
        != Some(EXO_OFFER_TYPE)
    {
        return Json(json!({ "offers": [] }));
    }
    let bought = bought_exo_types(&context);
    let offers: Vec<Value> = PURCHASABLE_EXOS
        .iter()
        .enumerate()
        .map(|(order, exo)| {
            json!({
                "offerId": exo.offer_id(),
                "offerType": EXO_OFFER_TYPE,
                "order": order,
                "purchased": bought.contains(&exo.exo_type),
                "repeatable": false,
                "costs": [{ "pricePointId": "default", "price": [javelin_tokens(1)] }],
                "resultUnlockIds": exo.unlock_ids(),
            })
        })
        .collect();
    Json(json!({ "offers": offers }))
}

pub async fn buy_offers(State(context): State<Context>, body: Bytes) -> Json<Value> {
    let request: Value = serde_json::from_slice(&body).unwrap_or(Value::Null);
    let requested: Vec<&str> = request["offers"]
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(|offer| offer["offerId"].as_str())
        .collect();
    let newly_bought: Vec<&PurchasableExo> = PURCHASABLE_EXOS
        .iter()
        .filter(|exo| requested.contains(&exo.offer_id().as_str()))
        .filter(|exo| !bought_exo_types(&context).contains(&exo.exo_type))
        .take(usize::try_from(remaining_javelin_tokens(&context)).unwrap_or(0))
        .collect();
    let offer_ids: Vec<String> = newly_bought.iter().map(|exo| exo.offer_id()).collect();
    context
        .state
        .lock()
        .expect("fichier d'état")
        .buy_offers(&offer_ids.iter().map(String::as_str).collect::<Vec<_>>());
    Json(json!({
        "currencyGain": [],
        "currencyBalances": [javelin_tokens(remaining_javelin_tokens(&context))],
        "unlockGains": newly_bought.iter().flat_map(|exo| exo.unlock_ids()).collect::<Vec<_>>(),
    }))
}

pub async fn owned_javelins(State(context): State<Context>) -> Json<Value> {
    let bought = bought_exo_types(&context);
    let starting = json!({ "name": STARTING_EXO_NAME, "exoType": 0, "owned": true });
    let purchasable = PURCHASABLE_EXOS.iter().map(|exo| {
        json!({ "name": exo.name, "exoType": exo.exo_type, "owned": bought.contains(&exo.exo_type) })
    });
    Json(Value::Array(
        std::iter::once(starting).chain(purchasable).collect(),
    ))
}

pub async fn set_owned_javelins(State(context): State<Context>, body: Bytes) -> Json<Value> {
    let request: Value = serde_json::from_slice(&body).unwrap_or(Value::Null);
    let owned: Vec<&str> = request["owned"]
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(Value::as_str)
        .collect();
    let offers: Vec<String> = PURCHASABLE_EXOS
        .iter()
        .filter(|exo| owned.contains(&exo.name))
        .map(PurchasableExo::offer_id)
        .collect();
    context
        .state
        .lock()
        .expect("fichier d'état")
        .set_bought_offers(&offers);
    owned_javelins(State(context)).await
}
