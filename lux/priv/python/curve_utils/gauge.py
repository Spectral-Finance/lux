from web3 import Web3

GAUGE_ABI = [
    {
        "name": "deposit",
        "outputs": [],
        "inputs": [
            {"type": "uint256", "name": "_value"}
        ],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "name": "withdraw",
        "outputs": [],
        "inputs": [
            {"type": "uint256", "name": "_value"}
        ],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "name": "claim_rewards",
        "outputs": [],
        "inputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    }
]

def deposit(w3: Web3, gauge_address: str, amount: int, user_address: str) -> dict:
    contract = w3.eth.contract(address=w3.to_checksum_address(gauge_address), abi=GAUGE_ABI)
    func = contract.functions.deposit(amount)
    data = func.encode_abi() if hasattr(func, 'encode_abi') else func.build_transaction({'from': user_address, 'nonce': 0, 'gas': 0, 'gasPrice': 0})['data']
    return {
        'to': w3.to_checksum_address(gauge_address),
        'from': user_address,
        'data': data
    }

def withdraw(w3: Web3, gauge_address: str, amount: int, user_address: str) -> dict:
    contract = w3.eth.contract(address=w3.to_checksum_address(gauge_address), abi=GAUGE_ABI)
    func = contract.functions.withdraw(amount)
    data = func.encode_abi() if hasattr(func, 'encode_abi') else func.build_transaction({'from': user_address, 'nonce': 0, 'gas': 0, 'gasPrice': 0})['data']
    return {
        'to': w3.to_checksum_address(gauge_address),
        'from': user_address,
        'data': data
    }

def claim_rewards(w3: Web3, gauge_address: str, user_address: str) -> dict:
    contract = w3.eth.contract(address=w3.to_checksum_address(gauge_address), abi=GAUGE_ABI)
    func = contract.functions.claim_rewards()
    data = func.encode_abi() if hasattr(func, 'encode_abi') else func.build_transaction({'from': user_address, 'nonce': 0, 'gas': 0, 'gasPrice': 0})['data']
    return {
        'to': w3.to_checksum_address(gauge_address),
        'from': user_address,
        'data': data
    }
