use sha2::{Sha256, Digest as Sha2Digest};
use sha3::{Keccak256, Digest as Sha3Digest};
use hmac::{Hmac, Mac};
use sha2::Sha512;

type HmacSha512 = Hmac<Sha512>;

pub fn sha256(input: &[u8]) -> Vec<u8> {
    let mut hasher = Sha256::new();
    hasher.update(input);
    hasher.finalize().to_vec()
}

pub fn keccak256(input: &[u8]) -> Vec<u8> {
    let mut hasher = Keccak256::new();
    hasher.update(input);
    hasher.finalize().to_vec()
}

pub fn sha256_hex(input: &str) -> String {
    hex::encode(sha256(input.as_bytes()))
}

pub fn keccak256_hex(input: &str) -> String {
    hex::encode(keccak256(input.as_bytes()))
}

pub fn hmac_sha512(key: &[u8], message: &[u8]) -> Vec<u8> {
    let mut mac = HmacSha512::new_from_slice(key)
        .expect("HMAC can take key of any size");
    mac.update(message);
    mac.finalize().into_bytes().to_vec()
}

pub fn ethereum_address_from_public_key(pubkey: &[u8]) -> String {
    let hash = keccak256(&pubkey[1..]);
    format!("0x{}", hex::encode(&hash[12..]))
}

pub fn personal_sign_hash(message: &str) -> Vec<u8> {
    let prefix = format!(
        "\x19Ethereum Signed Message:\n{}{}",
        message.len(),
        message
    );
    keccak256(prefix.as_bytes())
}

pub fn hash_concat(a: &[u8], b: &[u8]) -> Vec<u8> {
    let mut combined = Vec::with_capacity(a.len() + b.len());
    combined.extend_from_slice(a);
    combined.extend_from_slice(b);
    keccak256(&combined)
}
