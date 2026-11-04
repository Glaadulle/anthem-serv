use std::time::{SystemTime, UNIX_EPOCH};

use axum::{
    extract::{
        State,
        ws::{Message, WebSocket, WebSocketUpgrade},
    },
    response::Response,
};
use serde_json::{Value, json};

use crate::Context;

pub async fn connect(State(context): State<Context>, upgrade: WebSocketUpgrade) -> Response {
    upgrade.on_upgrade(move |socket| listen(socket, context))
}

pub fn event(persona_id: u64, domain: &str, event_type: &str, payload: Value) -> Value {
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |elapsed| elapsed.as_millis() as u64);
    let mut event = json!({
        "routingKey": format!("prod.{domain}.{persona_id}"),
        "personaId": persona_id,
        "eventType": event_type,
        "timestamp": timestamp,
        "payload": payload.clone(),
    });
    if let (Some(event), Value::Object(fields)) = (event.as_object_mut(), payload) {
        event.extend(fields);
    }
    event
}

fn acknowledgement(request: &[u8]) -> Option<Value> {
    let request: Value = serde_json::from_slice(request).ok()?;
    let action = request["action"].as_str()?;
    matches!(action, "register" | "deregister").then(|| {
        json!({
            "action": action,
            "keys": request["keys"],
            "status": "SUCCESS",
            "result": "SUCCESS",
        })
    })
}

async fn listen(mut socket: WebSocket, context: Context) {
    println!("EBS : connexion WebSocket ouverte");
    let mut events = context.events.subscribe();
    loop {
        tokio::select! {
            incoming = socket.recv() => match incoming {
                Some(Ok(Message::Text(text))) => println!("EBS <- texte : {text}"),
                Some(Ok(Message::Binary(bytes))) => {
                    println!("EBS <- {}", String::from_utf8_lossy(&bytes));
                    if let Some(ack) = acknowledgement(&bytes) {
                        println!("EBS -> {ack}");
                        if socket.send(Message::Binary(ack.to_string().into_bytes().into())).await.is_err() {
                            break;
                        }
                    }
                }
                Some(Ok(Message::Close(frame))) => {
                    println!("EBS : fermeture demandée {frame:?}");
                    break;
                }
                Some(Ok(Message::Ping(_) | Message::Pong(_))) => {}
                Some(Err(_)) | None => break,
            },
            Ok(event) = events.recv() => {
                println!("EBS -> {event}");
                if socket.send(Message::Binary(event.to_string().into_bytes().into())).await.is_err() {
                    break;
                }
            }
        }
    }
    println!("EBS : connexion WebSocket fermée");
}
