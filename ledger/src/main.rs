//! Every Leca payment is a transfer on a Nunchi coin ledger.
//!
//! The journal is the durable list of payments. Replaying it through
//! `nunchi_coins::Ledger` produces the authenticated state root.

use std::env;
use std::fs::{self, OpenOptions};
use std::io::{Read, Seek, SeekFrom, Write};
use std::path::Path;
use std::process::ExitCode;

use commonware_runtime::{deterministic, Runner as _};
use nunchi_coins::{
    external_account_id, CoinOperation, CoinSpec, Ledger, PrivateKey, TokenName, TokenSymbol,
    Transaction,
};
use nunchi_common::{NoopEventSink, QmdbState};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct Entry {
    id: String,
    kind: String,
    from: String,
    to: String,
    cents: u64,
    #[serde(default)]
    fee_cents: u64,
    #[serde(default)]
    tip_cents: u64,
    #[serde(default)]
    memo: String,
}

fn main() -> ExitCode {
    let path = env::args()
        .nth(1)
        .unwrap_or_else(|| "/var/lib/leca-auth/ledger.jsonl".to_string());
    let mut incoming = String::new();
    if let Err(err) = std::io::stdin().read_to_string(&mut incoming) {
        eprintln!("leca-ledger: {err}");
        return ExitCode::from(1);
    }
    let entry: Entry = match serde_json::from_str(incoming.trim()) {
        Ok(entry) => entry,
        Err(err) => {
            eprintln!("leca-ledger: {err}");
            return ExitCode::from(2);
        }
    };
    if let Err(err) = validate(&entry) {
        eprintln!("leca-ledger: {err}");
        return ExitCode::from(2);
    }
    let encoded = match serde_json::to_string(&entry) {
        Ok(encoded) => encoded,
        Err(err) => {
            eprintln!("leca-ledger: {err}");
            return ExitCode::from(1);
        }
    };
    match commit(Path::new(&path), &entry, &encoded) {
        Ok(posted) => {
            println!(
                "{}",
                success_line(&entry.id, &posted.root, posted.duplicate)
            );
            ExitCode::SUCCESS
        }
        Err(err) => {
            eprintln!("leca-ledger: {err}");
            ExitCode::from(err.code())
        }
    }
}

struct Posted {
    root: String,
    duplicate: bool,
}

enum Fail {
    Bad(String),
    Broken(String),
}

impl Fail {
    fn code(&self) -> u8 {
        match self {
            Fail::Bad(_) => 2,
            Fail::Broken(_) => 1,
        }
    }
}

impl std::fmt::Display for Fail {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Fail::Bad(err) | Fail::Broken(err) => f.write_str(err),
        }
    }
}

fn id_ok(id: &str) -> bool {
    let n = id.len();
    (8..=25).contains(&n) && id.bytes().all(|byte| byte.is_ascii_alphanumeric())
}

fn payment_total(cents: u64, fee: u64, tip: u64) -> Option<u128> {
    let total = u128::from(cents) + u128::from(fee) + u128::from(tip);
    if total == 0 {
        None
    } else {
        Some(total)
    }
}

fn validate(entry: &Entry) -> Result<(), String> {
    if !id_ok(&entry.id) {
        return Err("id must be 8 to 25 letters or digits".to_string());
    }
    if entry.from.is_empty() || entry.to.is_empty() {
        return Err("from and to are required".to_string());
    }
    if entry.from.bytes().any(|byte| byte < 0x20) || entry.to.bytes().any(|byte| byte < 0x20) {
        return Err("from and to must be one line".to_string());
    }
    if payment_total(entry.cents, entry.fee_cents, entry.tip_cents).is_none() {
        return Err("amount is zero".to_string());
    }
    Ok(())
}

fn success_line(id: &str, root: &str, duplicate: bool) -> String {
    serde_json::json!({
        "ok": true,
        "root": root,
        "id": id,
        "duplicate": duplicate,
    })
    .to_string()
}

/// `Ok(true)` is the same payment again. `Ok(false)` is a new id.
/// A repeated id with a different body is refused.
fn admission(lines: &[String], encoded: &str, id: &str) -> Result<bool, String> {
    let incoming: serde_json::Value =
        serde_json::from_str(encoded).map_err(|err| err.to_string())?;
    for line in lines {
        let Ok(existing) = serde_json::from_str::<serde_json::Value>(line) else {
            continue;
        };
        let Some(existing_id) = existing.get("id").and_then(|value| value.as_str()) else {
            continue;
        };
        if existing_id != id {
            continue;
        }
        if existing == incoming {
            return Ok(true);
        }
        return Err("duplicate id with a different payment".to_string());
    }
    Ok(false)
}

fn commit(path: &Path, entry: &Entry, encoded: &str) -> Result<Posted, Fail> {
    with_journal(path, |file| {
        let mut lines = read_lines(file)?;
        let duplicate = admission(&lines, encoded, &entry.id).map_err(Fail::Bad)?;
        if !duplicate {
            lines.push(encoded.to_string());
        }
        let entries = parse_lines(&lines).map_err(Fail::Broken)?;
        let root = replay(&entries).map_err(Fail::Broken)?;
        if !duplicate {
            write_line(file, encoded)?;
        }
        Ok(Posted { root, duplicate })
    })
}

fn with_journal<T>(
    path: &Path,
    body: impl FnOnce(&mut std::fs::File) -> Result<T, Fail>,
) -> Result<T, Fail> {
    if let Some(parent) = path.parent() {
        if parent.components().next().is_some() {
            fs::create_dir_all(parent).map_err(|err| Fail::Broken(err.to_string()))?;
        }
    }
    let mut file = OpenOptions::new()
        .create(true)
        .truncate(false)
        .read(true)
        .write(true)
        .open(path)
        .map_err(|err| Fail::Broken(err.to_string()))?;
    file.lock().map_err(|err| Fail::Broken(err.to_string()))?;
    let result = body(&mut file);
    let _ = file.unlock();
    result
}

fn read_lines(file: &mut std::fs::File) -> Result<Vec<String>, Fail> {
    file.seek(SeekFrom::Start(0))
        .map_err(|err| Fail::Broken(err.to_string()))?;
    let mut text = String::new();
    file.read_to_string(&mut text)
        .map_err(|err| Fail::Broken(err.to_string()))?;
    Ok(text
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .map(str::to_string)
        .collect())
}

fn write_line(file: &mut std::fs::File, line: &str) -> Result<(), Fail> {
    file.seek(SeekFrom::End(0))
        .map_err(|err| Fail::Broken(err.to_string()))?;
    writeln!(file, "{line}").map_err(|err| Fail::Broken(err.to_string()))?;
    file.sync_all().map_err(|err| Fail::Broken(err.to_string()))
}

fn parse_lines(lines: &[String]) -> Result<Vec<Entry>, String> {
    Ok(lines
        .iter()
        .filter_map(|line| serde_json::from_str(line).ok())
        .collect())
}

fn replay(entries: &[Entry]) -> Result<String, String> {
    let entries = entries.to_vec();
    let runner = deterministic::Runner::default();
    runner.start(|context| async move { apply(context, entries).await })
}

async fn apply(context: deterministic::Context, entries: Vec<Entry>) -> Result<String, String> {
    let db = QmdbState::init(context, "leca-ledger")
        .await
        .map_err(|err| err.to_string())?;
    let mut ledger = Ledger::new(db);
    let issuer_key = PrivateKey::ed25519_from_seed(seed_of("leca"));
    let issuer = external_account_id(&issuer_key.public_key());
    let spec = CoinSpec::new(
        TokenSymbol::new("USD").map_err(|err| err.to_string())?,
        TokenName::new("Leca dollar").map_err(|err| err.to_string())?,
        2,
        0,
        None,
    );
    let coin = ledger
        .create_token(issuer.clone(), spec)
        .await
        .map_err(|err| err.to_string())?;

    for entry in entries {
        let Some(total) = payment_total(entry.cents, entry.fee_cents, entry.tip_cents) else {
            continue;
        };
        let price = u128::from(entry.cents);
        let fee = u128::from(entry.fee_cents);
        let tip = u128::from(entry.tip_cents);
        let from = account(&entry.from);
        let to = account(&entry.to);
        let nonce = ledger.nonce(&issuer).await.map_err(|err| err.to_string())?;
        let mint = Transaction::sign(
            &issuer_key,
            nonce,
            CoinOperation::Mint {
                coin,
                to: from.clone(),
                amount: total,
            },
        );
        ledger
            .apply_transaction(&mint, NoopEventSink)
            .await
            .map_err(|err| err.to_string())?;
        if price > 0 {
            ledger
                .transfer(&from, &to, coin, price)
                .await
                .map_err(|err| err.to_string())?;
        }
        if fee > 0 {
            ledger
                .transfer(&from, &issuer, coin, fee)
                .await
                .map_err(|err| err.to_string())?;
        }
        if tip > 0 {
            ledger
                .transfer(&from, &to, coin, tip)
                .await
                .map_err(|err| err.to_string())?;
        }
        let _ = &entry.kind;
        let _ = &entry.memo;
    }

    let root = ledger.commit().await.map_err(|err| err.to_string())?;
    Ok(hex_digest(&root))
}

fn account(name: &str) -> nunchi_coins::Address {
    external_account_id(&PrivateKey::ed25519_from_seed(seed_of(name)).public_key())
}

fn seed_of(name: &str) -> u64 {
    let mut hash = 0xcbf29ce484222325u64;
    for byte in name.as_bytes() {
        hash ^= u64::from(*byte);
        hash = hash.wrapping_mul(0x100000001b3);
    }
    hash
}

fn hex_digest(digest: &impl AsRef<[u8]>) -> String {
    digest
        .as_ref()
        .iter()
        .map(|byte| format!("{byte:02x}"))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn entry_json(id: &str, cents: u64) -> String {
        serde_json::json!({
            "id": id,
            "kind": "goods",
            "from": "email:ada@leca.app",
            "to": "Honda ADV 350",
            "cents": cents,
            "feeCents": 5,
            "tipCents": 0,
            "memo": ""
        })
        .to_string()
    }

    #[test]
    fn same_id_with_a_different_amount_is_refused() {
        let first = entry_json("LECA1019211100ABCDEF", 100);
        let again = entry_json("LECA1019211100ABCDEF", 100);
        let changed = entry_json("LECA1019211100ABCDEF", 250);
        let other = entry_json("LECA1019211101ABCDEF", 250);
        let lines = vec![first];
        assert!(admission(&lines, &again, "LECA1019211100ABCDEF").unwrap());
        assert!(admission(&lines, &changed, "LECA1019211100ABCDEF").is_err());
        assert!(!admission(&lines, &other, "LECA1019211101ABCDEF").unwrap());
    }

    #[test]
    fn a_zero_payment_is_refused_and_parts_do_not_wrap() {
        assert!(payment_total(0, 0, 0).is_none());
        assert_eq!(
            payment_total(u64::MAX, u64::MAX, 1),
            Some((u128::from(u64::MAX) * 2) + 1)
        );
    }

    #[test]
    fn the_receipt_is_json_even_when_the_id_has_a_quote() {
        assert!(id_ok("LECA1019211100ABCDEF"));
        assert!(!id_ok("LECA\"oops"));
        let text = success_line("ab\"cd", "root", false);
        let value: serde_json::Value = serde_json::from_str(&text).unwrap();
        assert_eq!(value["id"], "ab\"cd");
        assert_eq!(value["ok"], true);
        assert_eq!(value["duplicate"], false);
    }
}
