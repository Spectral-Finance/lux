from ethers.contract import Contract
from ethers.signer import Signer
from ethers.provider import Provider

GAUGE_ABI = [
    {"constant": False, "inputs": [], "name": "claim_rewards", "outputs": [],
     "payable": False, "stateMutability": "nonpayable", "type": "function"},
    {"constant": True, "inputs": [], "name": "reward_contract", "outputs": [{"name": "", "type": "address"}],
     "payable": False, "stateMutability": "view", "type": "function"}
]

POOL_GAUGE_MAP = {
    "3crypto": "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
    "aave": "0x000000003988d5541Ab068c586F8Ef090397dA5a",
    "fraxswap": "0x000000003988d5541Ab068c586F8Ef090397dA5b",
    "yearn": "0x000000003988d5541Ab068c586F8Ef090397dA5c",
    "cvxcrv": "0x000000003988d5541Ab068c586F8Ef090397dA5d",
    "compound": "0x000000003988d5541Ab068c586F8Ef090397dA5e",
    "skyv2": "0x000000003988d5541Ab068c586F8Ef090397dA5f"
}

pool_name = params["pool_name"]
account = params.get("account", address) or address

gauge_address = POOL_GAUGE_MAP.get(pool_name, "")
if not gauge_address:
    raise Exception(f"Unknown pool: {pool_name}")

provider = Provider(rpc_url, chain_id=int(chain_id))
signer = Signer(private_key, provider)

gauge_contract = Contract(gauge_address, GAUGE_ABI)
tx = gauge_contract.claim_rewards(sender=signer)
receipt = tx.wait()

result = {
    "tx_hash": receipt.transactionHash.hex(),
    "pool": pool_name,
    "gauge_address": gauge_address
}
result
