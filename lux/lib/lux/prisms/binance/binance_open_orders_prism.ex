defmodule Lux.Prisms.Binance.BinanceOpenOrdersPrism do
  @moduledoc """
  A prism that fetches open orders on the Binance exchange.
  """

  use Lux.Prism,
    name: "Binance Open Orders",
    description: "Fetches open orders on Binance Spot and Futures",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'ETHUSDT'). If not provided, gets open orders for all symbols."
        },
        market_type: %{
          type: :string,
          description: "Market to query: SPOT or FUTURES",
          enum: ["SPOT", "FUTURES"],
          default: "SPOT"
        },
        testnet: %{
          type: :boolean,
          description: "Use Binance Testnet",
          default: false
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        open_orders: %{type: :array, description: "List of open orders"}
      },
      required: ["status", "open_orders"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, api_key} <- get_api_key(),
         {:ok, api_secret} <- get_api_secret(),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("binance.client"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("binance_utils.setup"),
         {:ok, result} <- fetch_open_orders(api_key, api_secret, input) do
      {:ok, %{status: "success", open_orders: result}}
    else
      {:error, :missing_api_key} -> {:error, "Binance API Key is not configured"}
      {:error, :missing_api_secret} -> {:error, "Binance API Secret is not configured"}
      {:ok, %{"success" => false, "error" => error}} -> {:error, "Failed to import required packages: #{error}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_api_key, do: {:ok, Config.binance_api_key()}
  rescue RuntimeError -> {:error, :missing_api_key}

  defp get_api_secret, do: {:ok, Config.binance_api_secret()}
  rescue RuntimeError -> {:error, :missing_api_secret}

  defp fetch_open_orders(api_key, api_secret, params) do
    python_result =
      python variables: %{api_key: api_key, api_secret: api_secret, params: params} do
        ~PY"""
        from binance_utils.setup import setup
        import traceback

        try:
            market_type = params.get("market_type", "SPOT")
            testnet = params.get("testnet", False)
            client = setup(api_key, api_secret, testnet=testnet)

            symbol = params.get("symbol")
            
            if market_type == "SPOT":
                if symbol:
                    orders = client.get_open_orders(symbol=symbol)
                else:
                    orders = client.get_open_orders()
            elif market_type == "FUTURES":
                if symbol:
                    orders = client.futures_get_open_orders(symbol=symbol)
                else:
                    orders = client.futures_get_open_orders()
            else:
                orders = {"error": f"Unsupported market type: {market_type}"}
            
            orders
        except Exception as e:
            {"error": str(e), "traceback": traceback.format_exc()}
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_list(result) -> {:ok, result}
      result when is_map(result) -> {:ok, result}
    end
  end
end
