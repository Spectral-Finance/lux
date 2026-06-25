from ethers.contract import Contract
from ethers.signer import Signer
from ethers.provider import Provider

ERC20_ABI = [
    {"constant": True, "inputs": [{"name": "_owner", "type": "address"}],
     "name": "balanceOf", "outputs": [{"name": "balance", "type": "uint256"}],
     "payable": False, "stateMutability": "view", "type": "function"},
    {"constant": False, "inputs": [{"name": "_spender", "type": "address"}, {"name": "_value", "type": "uint256"}],
     "name": "approve", "outputs": [{"name": "", "type": "bool"}],
     "payable": False, "stateMutability": "nonpayable", "type": "function"}
]

GAUGE_ABI = [
    {"constant": False, "inputs": [{"name": "value", "type": "uint256"}],
     "name": "deposit", "outputs": [],
     "payable": False, "stateMutability": "nonpayable", "type": "function"},
    {"constant": False, "inputs": [{"name": "value", "type": "uint256"}],
     "name": "withdraw", "outputs": [],
     "payable": False, "stateMutability": "nonpayable", "type": "function"}
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
amount = int(params["amount"])
account = params.get("account", address) or address

gauge_address = POOL_GAUGE_MAP.get(pool_name, "")
if not gauge_address:
    raise Exception(f"Unknown pool: {pool_name}")

provider = Provider(rpc_url, chain_id=int(chain_id))
signer = Signer(private_key, provider)

lp_token_addr = gauge_address
lp_contract = Contract(lp_token_addr, ERC20_ABI)
gauge_contract = Contract(gauge_address, GAUGE_ABI)
allowance = lp_contract.allowance(signer.address, gauge_address)
if allowance < amount:
    tx = lp_contract.approve(gauge_address, 2**256 - 1, sender=signer)
    tx.wait()

tx = gauge_contract.deposit(amount, sender=signer)
receipt = tx.wait()

result = {
    "tx_hash": receipt.transactionHash.hex(),
    "pool": pool_name,
    "amount_staked": params["amount"],
    "gauge_address": gauge_address
}
result
