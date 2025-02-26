import eth_account
from eth_account.signers.local import LocalAccount

from hyperliquid.exchange import Exchange
from hyperliquid.info import Info

def setup(private_key, address, base_url=None, skip_ws=False):
    account: LocalAccount = eth_account.Account.from_key(private_key)

    if address == "":
        address = account.address
    print("Running with account address:", address)

    if address != account.address:
        print("Running with agent address:", account.address)

    info = Info(base_url, skip_ws)

    exchange = Exchange(account, base_url, account_address=address)

    return address, info, exchange
