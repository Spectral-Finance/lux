defmodule Lux.Prisms.Binance.BinanceCancelOrderPrism do
  @moduledoc """
  A prism that cancels an order on the Binance exchange.
  """

  use Lux.Prism,
    name: "Binance Cancel Order",
    description: "Cancels an order on Binance Spot and Futures",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'ETHUSDT')"
        },
        orderId: %{
          type: :number,
          description: "Order ID to cancel"
        },
        origClientOrderId: %{
          type: :string,
          description: "Client Order ID to cancel (alternative to orderId)"
        },
        market_type: %{
          type: :string,
          description: "Market to trade on: SPOT or FUTURES",
          enum: ["SPOT", "FUTURES"],
          default: "SPOT"
        },
        testnet: %{
          type: :boolean,
          description: "Use Binance Testnet",
          default: false
        }
      },
      required: ["symbol"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        result: %{type: :object, description: "Raw response from Binance API"}
      },
      required: ["status", "result"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python

  def handler(input, _ctx) do
    if not Map.has_key?(input, :orderId) and not Map.has_key?(input, :origClientOrderId) do
      {:error, "Either orderId or origClientOrderId must be provided"}
    else
      with {:ok, api_key} <- get_api_key(),
           {:ok, api_secret} <- get_api_secret(),
           {:ok, %{"success" => true}} <- Lux.Python.import_package("binance.client"),
           {:ok, %{"success" => true}} <- Lux.Python.import_package("binance_utils.setup"),
           {:ok, result} <- cancel_order(api_key, api_secret, input) do
        {:ok, %{status: "success", result: result}}
      else
        {:error, :missing_api_key} ->
          {:error, "Binance API Key is not configured"}

        {:error, :missing_api_secret} ->
          {:error, "Binance API Secret is not configured"}

        {:ok, %{"success" => false, "error" => error}} ->
          {:error, "Failed to import required packages: #{error}"}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp get_api_key do
    {:ok, Config.binance_api_key()}
  rescue
    RuntimeError -> {:error, :missing_api_key}
  end

  defp get_api_secret do
    {:ok, Config.binance_api_secret()}
  rescue
    RuntimeError -> {:error, :missing_api_secret}
  end

  defp cancel_order(api_key, api_secret, params) do
    python_result =
      python variables: %{
               api_key: api_key,
               api_secret: api_secret,
               params: params
             } do
        ~PY"""
        from binance_utils.setup import setup
        import traceback

        try:
            market_type = params.get("market_type", "SPOT")
            testnet = params.get("testnet", False)
            client = setup(api_key, api_secret, testnet=testnet)

            cancel_params = {
                "symbol": params["symbol"]
            }

            if "orderId" in params:
                cancel_params["orderId"] = params["orderId"]
            if "origClientOrderId" in params:
                cancel_params["origClientOrderId"] = params["origClientOrderId"]

            if market_type == "SPOT":
                result = client.cancel_order(**cancel_params)
            elif market_type == "FUTURES":
                result = client.futures_cancel_order(**cancel_params)
            else:
                result = {"error": f"Unsupported market type: {market_type}"}
            
            result
        except Exception as e:
            {"error": str(e), "traceback": traceback.format_exc()}
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end
end
