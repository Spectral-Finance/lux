from web3 import Web3

STABLESWAP_ABI = [
    {
        "name": "get_virtual_price",
        "outputs": [{"type": "uint256", "name": ""}],
        "inputs": [],
        "stateMutability": "view",
        "type": "function",
        "gas": 1050275
    },
    {
        "name": "add_liquidity",
        "outputs": [],
        "inputs": [
            {"type": "uint256[3]", "name": "amounts"},
            {"type": "uint256", "name": "min_mint_amount"}
        ],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "name": "remove_liquidity",
        "outputs": [],
        "inputs": [
            {"type": "uint256", "name": "_amount"},
            {"type": "uint256[3]", "name": "min_amounts"}
        ],
        "stateMutability": "nonpayable",
        "type": "function"
    }
]

def get_virtual_price(w3: Web3, pool_address: str) -> int:
    contract = w3.eth.contract(address=w3.to_checksum_address(pool_address), abi=STABLESWAP_ABI)
    return contract.functions.get_virtual_price().call()

def add_liquidity(w3: Web3, pool_address: str, amounts: list, min_mint_amount: int, user_address: str) -> dict:
    contract = w3.eth.contract(address=w3.to_checksum_address(pool_address), abi=STABLESWAP_ABI)
    # Return dry-run payload without hitting live RPC
    func = contract.functions.add_liquidity(amounts, min_mint_amount)
    data = func.encode_abi() if hasattr(func, 'encode_abi') else func.build_transaction({'from': user_address, 'nonce': 0, 'gas': 0, 'gasPrice': 0})['data']
    return {
        'to': w3.to_checksum_address(pool_address),
        'from': user_address,
        'data': data
    }

def remove_liquidity(w3: Web3, pool_address: str, amount: int, min_amounts: list, user_address: str) -> dict:
    contract = w3.eth.contract(address=w3.to_checksum_address(pool_address), abi=STABLESWAP_ABI)
    func = contract.functions.remove_liquidity(amount, min_amounts)
    data = func.encode_abi() if hasattr(func, 'encode_abi') else func.build_transaction({'from': user_address, 'nonce': 0, 'gas': 0, 'gasPrice': 0})['data']
    return {
        'to': w3.to_checksum_address(pool_address),
        'from': user_address,
        'data': data
    }
