from ethers.contract import Contract
from ethers.signer import Signer
from ethers.provider import Provider
import time

ERC20_ABI = [
    {"constant": True, "inputs": [{"name": "_owner", "type": "address"}],
     "name": "balanceOf", "outputs": [{"name": "balance", "type": "uint256"}],
     "payable": False, "stateMutability": "view", "type": "function"},
    {"constant": False, "inputs": [{"name": "_spender", "type": "address"}, {"name": "_value", "type": "uint256"}],
     "name": "approve", "outputs": [{"name": "", "type": "bool"}],
     "payable": False, "stateMutability": "nonpayable", "type": "function"}
]

POOL_ABI = [
    {"constant": False, "inputs": [{"name": "amounts", "type": "uint256[]"},
        {"name": "min_amounts", "type": "uint256[]"}, {"name": "receiver", "type": "address"},
        {"name": "deadline", "type": "uint256"}],
     "name": "withdraw", "outputs": [{"name": "", "type": "uint256"}],
     "payable": False, "stateMutability": "nonpayable", "type": "function"}
]

POOL_ADDRESSES = {
    "3crypto": {"pool": "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
        "coins": ["0x6B175474E89094C44Da98b954EedeAC495271d0F", "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", "0xdAC17F958D2ee523a2206206994597C13D831ec7"]},
    "aave": {"pool": "0xDeBF20617708857ebe4F679508E7b7863a8A8EeE",
        "coins": ["0x6B175474E89094C44Da98b954EedeAC495271d0F", "0x6B175474E89094C44Da98b954EedeAC495271d0F", "0x6B175474E89094C44Da98b954EedeAC495271d0F"]},
    "fraxswap": {"pool": "0x3175Df0976dFA876431C2E9eD6B23616cb0666Cb",
        "coins": ["0x6B175474E89094C44Da98b954EedeAC495271d0F", "0x6B175474E89094C44Da98b954EedeAC495271d0F"]},
    "yearn": {"pool": "0xdb25c56F383bEc1fEdE6Ce0e3Df0b2b6Ca2B17Ad",
        "coins": ["0x6B175474E89094C44Da98b954EedeAC495271d0F", "0x6B175474E89094C44Da98b954EedeAC495271d0F"]},
    "cvxcrv": {"pool": "0/jBdAwXnA2tbdS",
        "coins": ["0x6B175474E89094C44Da98b954EedeAC495271d0F", "0x6B175474E89094C44Da98b954EedeAC495271d0F"]},
    "compound": {"pool": "0/KqrdWoMm1Erjb",
        "coins": ["0x6B175474E89094C44Da98b954EedeAC495271d0F", "0x6B175474E89094C44Da98b954EedeAC495271d0F"]},
    "skyv2": {"pool": "0/xPfMJfFfKeB",
        "coins": ["0x6B175474E89094C44Da98b954EedeAC495271d0F", "0x6B175474E89094C44Da98b954EedeAC495271d0F"]}
}

pool_name = params["pool_name"]
amounts = params["amounts"]
min_receive = params.get("min_receive", ["0"] * len(amounts))
if isinstance(min_receive, str):
    min_receive = [min_receive] * len(amounts)
account = params.get("account", address) or address

pool_info = POOL_ADDRESSES.get(pool_name, {})
pool_address = pool_info.get("pool", "")
coin_addresses = pool_info.get("coins", [])

if not pool_address:
    raise Exception(f"Unknown pool: {pool_name}")

provider = Provider(rpc_url, chain_id=int(chain_id))
signer = Signer(private_key, provider)

lp_token_addr = pool_address
lp_contract = Contract(lp_token_addr, ERC20_ABI)
pool_contract = Contract(pool_address, POOL_ABI)
allowance = lp_contract.allowance(signer.address, pool_address)
if allowance < int(amounts[0]) if amounts else 0:
    tx = lp_contract.approve(pool_address, 2**256 - 1, sender=signer)
    tx.wait()

deadline = int(time.time()) + 3600
int_amounts = [int(a) for a in amounts]
int_min = [int(m) if isinstance(m, str) else m for m in min_receive]

tx = pool_contract.withdraw(int_amounts, int_min, account or signer.address, deadline, sender=signer)
receipt = tx.wait()

result = {"tx_hash": receipt.transactionHash.hex(), "pool": pool_name, "amounts": amounts}
result
