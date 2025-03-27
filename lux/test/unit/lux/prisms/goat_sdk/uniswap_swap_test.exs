defmodule Lux.Prisms.GoatSdk.UniswapSwapTest do
  use UnitCase, async: true

  alias Lux.Prisms.GoatSdk.UniswapSwap

  @moduletag :unit

  setup do
    mock_python_code = """
    import sys

    class UniswapPlugin:
        def get_swap_quote(self, chain_id, token_in, token_out, amount, slippage):
            if token_in == "0x1234" and token_out == "0x5678":
                return {
                    "chain_id": chain_id,
                    "token_in": token_in,
                    "token_out": token_out,
                    "amount": amount,
                    "slippage": slippage,
                    "quote": "2000000000000000000"
                }
            else:
                raise Exception("Insufficient liquidity")

        def execute_swap(self, quote):
            return {"amount_received": quote["quote"]}

    class UniswapPluginOptions:
        pass

    # Create a module structure
    class goat_plugins:
        class uniswap:
            uniswap = UniswapPlugin()
            UniswapPluginOptions = UniswapPluginOptions

    # Add the module to sys.modules
    sys.modules["goat_plugins"] = goat_plugins
    sys.modules["goat_plugins.uniswap"] = goat_plugins.uniswap

    def import_package(name):
        if name in ["goat_plugins", "goat_plugins.uniswap"]:
            return {"success": True}
        return {"success": False, "error": "Package not found"}
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
    assert {:ok, %{amount_received: "2000000000000000000"}} = result
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

    # Remove the modules from sys.modules
    if "goat_plugins" in sys.modules:
        del sys.modules["goat_plugins"]
    if "goat_plugins.uniswap" in sys.modules:
        del sys.modules["goat_plugins.uniswap"]

    def import_package(name):
        return {"success": False, "error": "Package not found"}
    """

    {:ok, _} = Lux.Python.eval(mock_python_code)

    input = %{
      from_token: "0x1234",
      to_token: "0x5678",
      amount: "1000000000000000000"
    }

    result = UniswapSwap.handler(input, %{})
    assert {:error, "Failed to import required packages: No module named 'goat_plugins'"} = result
  end

  test "handler/2 uses default values for optional parameters" do
    input = %{
      from_token: "0x1234",
      to_token: "0x5678",
      amount: "1000000000000000000"
    }

    result = UniswapSwap.handler(input, %{})
    assert {:ok, %{amount_received: "2000000000000000000"}} = result
  end
end
