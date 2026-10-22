import eth_account
from eth_account.signers.local import LocalAccount
from hyperliquid.exchange import Exchange
from hyperliquid.info import Info
import logging

logger = logging.getLogger(__name__)

def setup(private_key, address, base_url=None, skip_ws=False):
    account: LocalAccount = eth_account.Account.from_key(private_key)

    if address == "":
        address = account.address
    logger.info(f"Initializing Hyperliquid with account: {address}")

    if address != account.address:
        logger.info(f"Agent address override: {account.address}")

    info = Info(base_url, skip_ws)
    exchange = Exchange(account, base_url, account_address=address)

    logger.info("Hyperliquid setup completed")
    return address, info, exchange