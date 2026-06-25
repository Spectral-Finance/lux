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
     "payable": False, "stateMutability": "nonpayable", "type": "function"},
    {"constant": True, "inputs": [{"name": "_owner", "type": "address"}, {"name": "_spender", "type": "address"}],
     "name": "allowance", "outputs": [{"name": "", "type": "uint256"}],
     "payable": False, "stateMutability": "view", "type": "function"}
]

POOL_ABI = [
    {"constant": False, "inputs": [{"name": "coin_from", "type": "uint256"}, {"name": "coin_to", "type": "uint256"},
        {"name": "amount", "type": "uint256"}, {"name": "expected", "type": "uint256"},
        {"name": "receiver", "type": "address"}, {"name": "deadline", "type": "uint256"}],
     "name": "exchange", "outputs": [],
     "payable": False, "stateMutability": "nonpayable", "type": "function"},
    {"constant": True, "inputs": [{"name": "coin_from", "type": "uint256"}, {"name": "coin_to", "type": "uint256"},
        {"name": "amount", "type": "uint256"}],
     "name": "get_dy", "outputs": [{"name": "", "type": "uint256"}],
     "payable": False, "stateMutability": "view", "type": "function"}
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
coin_from = int(params["coin_from"])
coin_to = int(params["coin_to"])
amount = int(params["amount"])
expected = int(params["expected"])
account = params.get("account", address) or address

pool_info = POOL_ADDRESSES.get(pool_name, {})
pool_address = pool_info.get("pool", "")
coin_addresses = pool_info.get("coins", [])

if not pool_address:
    raise Exception(f"Unknown pool: {pool_name}")

if coin_from >= len(coin_addresses) or coin_to >= len(coin_addresses):
    raise Exception(f"Coin indices out of range for pool {pool_name}")

provider = Provider(rpc_url, chain_id=int(chain_id))
signer = Signer(private_key, provider)

src_coin_addr = coin_addresses[coin_from]
token_contract = Contract(src_coin_addr, ERC20_ABI)
pool_contract = Contract(pool_address, POOL_ABI)
allowance = token_contract.allowance(signer.address, pool_address)
if allowance < amount:
    tx = token_contract.approve(pool_address, 2**256 - 1, sender=signer)
    tx.wait()

deadline = int(time.time()) + 3600

tx = pool_contract.exchange(coin_from, coin_to, amount, expected, account or signer.address, deadline, sender=signer)
receipt = tx.wait()

result = {
    "tx_hash": receipt.transactionHash.hex(),
    "pool": pool_name,
    "coin_from": coin_from,
    "coin_to": coin_to,
    "amount_in": params["amount"],
    "amount_out": str(expected)
}
result
