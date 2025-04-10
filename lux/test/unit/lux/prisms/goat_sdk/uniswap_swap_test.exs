defmodule Lux.Prisms.GoatSdk.UniswapSwapTest do
  use UnitCase, async: true

  alias Lux.Prisms.GoatSdk.UniswapSwap

  @moduletag :unit

  setup do
    mock_python_code = """
    import sys
    import asyncio

    class EVMWalletClient:
        def __init__(self, chain_id):
            self.chain_id = chain_id

        def get_chain(self):
            return {"id": self.chain_id}

        def get_address(self):
            return "0xmockwallet"

        def send_transaction(self, tx):
            return {"hash": "0xmocktxhash"}

    class UniswapService:
        async def get_quote(self, wallet_client, params):
            if params["tokenIn"] == "0x1234" and params["tokenOut"] == "0x5678":
                return {
                    "quote": {
                        "amount": "2000000000000000000",
                        "to": "0xuniswap",
                        "data": "0xmockdata"
                    }
                }
            else:
                raise Exception("Insufficient liquidity")

        async def check_approval(self, wallet_client, params):
            if params["token"] == "0x1234":
                return {"status": "approved"}
            return {
                "status": "needs_approval",
                "txHash": "0xapproval"
            }

        async def swap_tokens(self, wallet_client, params):
            if params["tokenIn"] == "0x1234" and params["tokenOut"] == "0x5678":
                return {"txHash": "0xswaphash"}
            else:
                raise Exception("Swap failed")

    class UniswapPluginOptions:
        def __init__(self, api_key=None, rpc_url=None):
            self.api_key = api_key
            self.rpc_url = rpc_url

    # Create a module structure
    class uniswap:
        def __init__(self, options=None):
            self.service = UniswapService()
            self.options = options or UniswapPluginOptions()

        async def get_quote(self, *args, **kwargs):
            return await self.service.get_quote(*args, **kwargs)

        async def check_approval(self, *args, **kwargs):
            return await self.service.check_approval(*args, **kwargs)

        async def swap_tokens(self, *args, **kwargs):
            return await self.service.swap_tokens(*args, **kwargs)

    # Create a module structure
    class goat_plugins:
        uniswap = uniswap
        UniswapPluginOptions = UniswapPluginOptions

    class goat_wallets:
        class evm:
            EVMWalletClient = EVMWalletClient

    # Add the module to sys.modules
    sys.modules["goat_plugins"] = goat_plugins
    sys.modules["goat_plugins.uniswap"] = goat_plugins
    sys.modules["goat_wallets"] = goat_wallets
    sys.modules["goat_wallets.evm"] = goat_wallets.evm

    def import_package(name):
        if name in ["goat_plugins", "goat_plugins.uniswap"]:
            return {"success": True}
        return {"success": False, "error": "No module named 'goat_plugins'"}
    """

    {:ok, _} = Lux.Python.eval(mock_python_code)
    :ok
  end

  test "handler/2 successfully executes a swap" do
    input = %{
      from_token: "0x1234",
      to_token: "0x5678",
      amount: "1000000000000000000",
      chain_id: 1,
      slippage: 50
    }

    result = UniswapSwap.handler(input, %{})
    assert {:ok, %{amount_received: "2000000000000000000", tx_hash: "0xswaphash"}} = result
  end

  test "handler/2 handles swap execution error" do
    input = %{
      from_token: "0x9999",
      to_token: "0x8888",
      amount: "1000000000000000000",
      chain_id: 1,
      slippage: 50
    }

    result = UniswapSwap.handler(input, %{})
    assert {:error, "Insufficient liquidity"} = result
  end

  test "handler/2 validates required parameters" do
    input = %{
      from_token: "0x1234",
      to_token: "0x5678"
    }

    result = UniswapSwap.handler(input, %{})
    assert {:error, "Missing required parameter: amount"} = result
  end

  test "handler/2 handles package import failure" do
    mock_python_code = """
    import sys

    # Remove the goat_wallets module from sys.modules
    if "goat_wallets.evm" in sys.modules:
        del sys.modules["goat_wallets.evm"]

    def import_package(name):
        return {"success": False, "error": "No module named 'goat_plugins'"}
    """

    {:ok, _} = Lux.Python.eval(mock_python_code)

    input = %{
      from_token: "0x1234",
      to_token: "0x5678",
      amount: "1000000000000000000"
    }

    result = UniswapSwap.handler(input, %{})
    assert {:error, "No module named 'goat_wallets.evm'; 'goat_wallets' is not a package"} = result
  end

  test "handler/2 uses default values for optional parameters" do
    input = %{
      from_token: "0x1234",
      to_token: "0x5678",
      amount: "1000000000000000000"
    }

    result = UniswapSwap.handler(input, %{})
    assert {:ok, %{amount_received: "2000000000000000000", tx_hash: "0xswaphash"}} = result
  end
end
