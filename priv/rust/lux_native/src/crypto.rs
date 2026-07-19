use sha2::{Digest, Sha256};
pub fn sha256_hash(data: &[u8]) -> Vec<u8> {
    let mut hasher = Sha256::new();
    hasher.update(data);
    hasher.finalize().to_vec()
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_sha256() { assert_eq!(sha256_hash(b"hello").len(), 32); }
}
