use aes_gcm::{
    Aes256Gcm, KeyInit,
    aead::{Aead, Payload},
};
use anyhow::{Context, Result, bail};
use argon2::{Algorithm, Argon2, Params, Version};
use rusqlite::Connection;
use serde::{Deserialize, Serialize};
use std::{env, fs, path::Path};

const MIGRATIONS: [&str; 6] = ["v1", "v3", "v4", "v5", "v6", "v7"];

#[derive(Serialize, Deserialize)]
struct AesFixture {
    producer: String,
    key_hex: String,
    nonce_hex: String,
    plaintext_hex: String,
    combined_hex: String,
}

#[derive(Serialize, Deserialize)]
struct ExportFixture {
    producer: String,
    version: u8,
    iterations: u32,
    memory_kib: u32,
    parallelism: u32,
    passphrase: String,
    salt_hex: String,
    nonce_hex: String,
    payload_hex: String,
    envelope_hex: String,
}

fn main() -> Result<()> {
    let mut args = env::args().skip(1);
    let command = args
        .next()
        .context("expected generate-rust or verify-swift")?;
    let root = args.next().context("expected isolated fixture directory")?;
    if args.next().is_some() {
        bail!("unexpected extra argument");
    }
    match command.as_str() {
        "generate-rust" => generate_rust(Path::new(&root)),
        "verify-swift" => verify_swift(Path::new(&root)),
        _ => bail!("unknown command {command}"),
    }
}

fn generate_rust(root: &Path) -> Result<()> {
    let output = root.join("rust");
    fs::create_dir_all(&output)?;
    let key: Vec<u8> = (0_u8..32).collect();
    let nonce: [u8; 12] = (0_u8..12).collect::<Vec<_>>().try_into().unwrap();
    let plaintext = b"synthetic-lokalite-secret";
    let combined = seal(&key, nonce, plaintext)?;
    write_json(
        &output.join("aes-value.json"),
        &AesFixture {
            producer: "rust-aes-gcm-0.11.0".into(),
            key_hex: hex::encode(&key),
            nonce_hex: hex::encode(nonce),
            plaintext_hex: hex::encode(plaintext),
            combined_hex: hex::encode(combined),
        },
    )?;

    let salt: Vec<u8> = (0_u8..32).collect();
    let export_nonce: [u8; 12] = (32_u8..44).collect::<Vec<_>>().try_into().unwrap();
    let payload = br#"{"API_KEY":"synthetic-value","UNICODE":"caf\u00e9"}"#;
    let passphrase = "synthetic passphrase";
    let parameters = (3, 65_536, 1);
    let export_key = derive(passphrase, &salt, parameters)?;
    let export_combined = seal(&export_key, export_nonce, payload)?;
    let mut envelope = vec![0x02];
    envelope.extend_from_slice(&parameters.0.to_be_bytes());
    envelope.extend_from_slice(&parameters.1.to_be_bytes());
    envelope.extend_from_slice(&parameters.2.to_be_bytes());
    envelope.extend_from_slice(&salt);
    envelope.extend_from_slice(&export_combined);
    write_json(
        &output.join("encrypted-export-v2.json"),
        &ExportFixture {
            producer: "rust-argon2-0.5.3+aes-gcm-0.11.0".into(),
            version: 2,
            iterations: parameters.0,
            memory_kib: parameters.1,
            parallelism: parameters.2,
            passphrase: passphrase.into(),
            salt_hex: hex::encode(salt),
            nonce_hex: hex::encode(export_nonce),
            payload_hex: hex::encode(payload),
            envelope_hex: hex::encode(envelope),
        },
    )
}

fn verify_swift(root: &Path) -> Result<()> {
    let input = root.join("swift");
    verify_crypto(&input)?;
    let copies = root.join("rust-written");
    fs::create_dir_all(&copies)?;
    for (index, migration) in MIGRATIONS.iter().enumerate() {
        let source = input.join(format!("schema-{migration}.db"));
        let db = Connection::open(&source)
            .with_context(|| format!("open Swift fixture {}", source.display()))?;
        let identifiers: Vec<String> = db
            .prepare("SELECT identifier FROM grdb_migrations ORDER BY rowid")?
            .query_map([], |row| row.get(0))?
            .collect::<rusqlite::Result<_>>()?;
        if identifiers != MIGRATIONS[..=index] {
            bail!("unexpected migration history for {migration}: {identifiers:?}");
        }
        let name: String = db.query_row(
            "SELECT name FROM projects WHERE id='project-synthetic'",
            [],
            |row| row.get(0),
        )?;
        if name != "Prøject 🚀" {
            bail!("UTF-8 project mismatch in {migration}");
        }
        let blob: Vec<u8> = db.query_row(
            "SELECT encrypted_value FROM secret_values WHERE id='value-synthetic'",
            [],
            |row| row.get(0),
        )?;
        if blob != [0, 255, 1, 2, 3, 254] {
            bail!("BLOB mismatch in {migration}");
        }
        let environment: Option<String> = db.query_row(
            "SELECT environment_id FROM secret_values WHERE id='value-synthetic'",
            [],
            |row| row.get(0),
        )?;
        if environment.as_deref() != (index >= 2).then_some("environment-default") {
            bail!("Active Environment relationship mismatch in {migration}");
        }
        if index >= 3 {
            let policy: String = db.query_row(
                "SELECT agent_access FROM secrets WHERE id='secret-synthetic'",
                [],
                |row| row.get(0),
            )?;
            if policy != "allowed" {
                bail!("agent policy mismatch in {migration}");
            }
        }
        if index >= 1 {
            let activity: String = db.query_row(
                "SELECT source FROM activity_log WHERE id='activity-synthetic'",
                [],
                |row| row.get(0),
            )?;
            if activity != "cli" {
                bail!("Activity Log mismatch in {migration}");
            }
        }
        if index >= 4 {
            let (agent, action): (Option<String>, String) = db.query_row(
                "SELECT agent,action FROM activity_log WHERE id='activity-synthetic'",
                [],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )?;
            if agent.as_deref() != Some("codex") || action != "read" {
                bail!("Activity Log attribution mismatch in {migration}");
            }
        }
        if index >= 5 {
            let peer_team: Option<String> = db.query_row(
                "SELECT peer_team FROM activity_log WHERE id='activity-synthetic'",
                [],
                |row| row.get(0),
            )?;
            if peer_team.as_deref() != Some("67S22M7P3P") {
                bail!("Activity Log peer team mismatch in {migration}");
            }
        }
        drop(db);

        let copy = copies.join(format!("schema-{migration}.db"));
        fs::copy(&source, &copy)?;
        let mut copied = Connection::open(&copy)?;
        let tx = copied.transaction()?;
        tx.execute(
            "UPDATE config SET value=value WHERE key='active_project_id'",
            [],
        )?;
        tx.commit()?;
    }
    Ok(())
}

fn verify_crypto(input: &Path) -> Result<()> {
    let aes: AesFixture = read_json(&input.join("aes-value.json"))?;
    let key = hex::decode(aes.key_hex)?;
    let plaintext = hex::decode(aes.plaintext_hex)?;
    let combined = hex::decode(aes.combined_hex)?;
    if open(&key, &combined)? != plaintext {
        bail!("Swift AES fixture plaintext mismatch");
    }
    for offset in [0, 12, combined.len() - 1] {
        let mut damaged = combined.clone();
        damaged[offset] ^= 1;
        if open(&key, &damaged).is_ok() {
            bail!("Swift AES fixture accepted mutation at {offset}");
        }
    }

    let export: ExportFixture = read_json(&input.join("encrypted-export-v2.json"))?;
    let envelope = hex::decode(export.envelope_hex)?;
    if envelope.first() != Some(&0x02) || envelope.len() < 73 {
        bail!("invalid Swift export envelope");
    }
    if u32::from_be_bytes(envelope[1..5].try_into()?) != export.iterations
        || u32::from_be_bytes(envelope[5..9].try_into()?) != export.memory_kib
        || u32::from_be_bytes(envelope[9..13].try_into()?) != export.parallelism
        || envelope[13..45] != hex::decode(export.salt_hex)?
        || envelope[45..57] != hex::decode(export.nonce_hex)?
    {
        bail!("Swift export header mismatch");
    }
    let salt = &envelope[13..45];
    let export_key = derive(
        &export.passphrase,
        salt,
        (export.iterations, export.memory_kib, export.parallelism),
    )?;
    if open(&export_key, &envelope[45..])? != hex::decode(export.payload_hex)? {
        bail!("Swift export payload mismatch");
    }
    if open(
        &derive(
            "wrong passphrase",
            salt,
            (export.iterations, export.memory_kib, export.parallelism),
        )?,
        &envelope[45..],
    )
    .is_ok()
    {
        bail!("Swift export accepted wrong passphrase");
    }
    let mut damaged = envelope[45..].to_vec();
    *damaged.last_mut().context("missing export tag")? ^= 1;
    if open(&export_key, &damaged).is_ok() {
        bail!("Swift export accepted a modified tag");
    }
    Ok(())
}

fn seal(key: &[u8], nonce: [u8; 12], plaintext: &[u8]) -> Result<Vec<u8>> {
    let cipher = Aes256Gcm::new_from_slice(key).map_err(|_| anyhow::anyhow!("invalid key"))?;
    let encrypted = cipher
        .encrypt(
            (&nonce).into(),
            Payload {
                msg: plaintext,
                aad: &[],
            },
        )
        .map_err(|_| anyhow::anyhow!("encryption failed"))?;
    let mut combined = nonce.to_vec();
    combined.extend_from_slice(&encrypted);
    Ok(combined)
}

fn open(key: &[u8], combined: &[u8]) -> Result<Vec<u8>> {
    if combined.len() < 28 {
        bail!("truncated combined value");
    }
    let cipher = Aes256Gcm::new_from_slice(key).map_err(|_| anyhow::anyhow!("invalid key"))?;
    let nonce: &[u8; 12] = combined[..12].try_into()?;
    cipher
        .decrypt(
            nonce.into(),
            Payload {
                msg: &combined[12..],
                aad: &[],
            },
        )
        .map_err(|_| anyhow::anyhow!("authentication failed"))
}

fn derive(passphrase: &str, salt: &[u8], parameters: (u32, u32, u32)) -> Result<[u8; 32]> {
    let params = Params::new(parameters.1, parameters.0, parameters.2, Some(32))
        .map_err(|error| anyhow::anyhow!("invalid Argon2 parameters: {error}"))?;
    let mut key = [0_u8; 32];
    Argon2::new(Algorithm::Argon2id, Version::V0x13, params)
        .hash_password_into(passphrase.as_bytes(), salt, &mut key)
        .map_err(|error| anyhow::anyhow!("Argon2id derivation failed: {error}"))?;
    Ok(key)
}

fn write_json<T: Serialize>(path: &Path, value: &T) -> Result<()> {
    fs::write(path, serde_json::to_vec_pretty(value)?)?;
    Ok(())
}

fn read_json<T: for<'de> Deserialize<'de>>(path: &Path) -> Result<T> {
    Ok(serde_json::from_slice(&fs::read(path)?)?)
}
