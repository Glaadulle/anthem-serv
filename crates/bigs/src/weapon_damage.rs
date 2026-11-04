use std::path::{Path, PathBuf};

use base64::Engine;
use serde_json::{Value, json};

/// Table des dégâts réglables (data/game/weapon_damage.json) : une ligne par arme et statistique, avec la classe vars
/// de la pièce (classNameHash), le champ (fieldOffset, typeId), la valeur d'origine et la valeur réglée.
pub struct WeaponDamage {
    path: Option<PathBuf>,
    rows: Vec<Value>,
}

impl WeaponDamage {
    pub fn empty() -> Self {
        Self {
            path: None,
            rows: Vec::new(),
        }
    }

    pub fn open(path: &str) -> Self {
        let rows = match std::fs::read(path) {
            Ok(bytes) => serde_json::from_slice(&bytes).unwrap_or_else(|error| {
                eprintln!("table des dégâts {path} illisible : {error}");
                Vec::new()
            }),
            Err(_) => {
                eprintln!("table des dégâts {path} absente : data/e3/tuning/table_degats.py la crée");
                Vec::new()
            }
        };
        Self {
            path: Some(PathBuf::from(path)),
            rows,
        }
    }

    pub fn editor_rows(&self) -> Vec<Value> {
        self.rows
            .iter()
            .map(|row| {
                json!({
                    "arme": row["arme"], "stat": row["stat"], "origine": row["origine"],
                    "reglee": row["reglee"], "reglable": override_field(row).is_some(),
                })
            })
            .collect()
    }

    pub fn adjust(&mut self, changes: &[Value]) {
        for change in changes {
            let Some(value) = change["reglee"].as_f64() else {
                continue;
            };
            if let Some(row) = self
                .rows
                .iter_mut()
                .find(|row| row["arme"] == change["arme"] && row["stat"] == change["stat"])
            {
                row["reglee"] = json!(value);
            }
        }
        if let Some(path) = &self.path
            && let Err(error) = write_atomically(path, &self.rows)
        {
            eprintln!("table des dégâts {} non écrite : {error}", path.display());
        }
    }

    /// Valeurs de GetTuningResponse : les lignes réglées (valeur réglée différente de l'origine) dont le champ est
    /// connu, regroupées par classe, car 0x140def880 remplace toute l'entrée d'une classe à chaque réponse.
    pub fn tuning_values(&self) -> Vec<Value> {
        let mut values: Vec<Value> = Vec::new();
        for row in &self.rows {
            let Some(variable) = override_field(row) else {
                continue;
            };
            if row["reglee"].as_f64() == row["origine"].as_f64() {
                continue;
            }
            match values
                .iter_mut()
                .find(|value| value["classNameHash"] == row["classNameHash"])
            {
                Some(value) => value["classData"]
                    .as_array_mut()
                    .expect("classData")
                    .push(variable),
                None => values.push(json!({
                    "className": row["classe"],
                    "classNameHash": row["classNameHash"],
                    "classData": [variable],
                })),
            }
        }
        values
    }
}

fn override_field(row: &Value) -> Option<Value> {
    let offset = row["fieldOffset"].as_u64()?;
    let type_id = row["typeId"].as_u64()?;
    let value = row["reglee"].as_f64()? as f32;
    Some(json!({
        "typeId": type_id,
        "dataBase64": base64::engine::general_purpose::STANDARD.encode(value.to_le_bytes()),
        "fieldOffset": offset,
    }))
}

fn write_atomically(path: &Path, rows: &[Value]) -> std::io::Result<()> {
    let temporary = path.with_extension("json.tmp");
    std::fs::write(&temporary, serde_json::to_vec_pretty(rows)?)?;
    std::fs::rename(&temporary, path)
}
