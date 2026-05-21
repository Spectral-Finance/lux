defmodule Lux.Prisms.Binance.BinanceExecuteOrderPrism do
  @moduledoc """
  A prism that executes orders on the Binance exchange (Spot and USD-M Futures).

  ## Example

      # Spot Limit order
      iex> Lux.Prisms.Binance.BinanceExecuteOrderPrism.run(%{
      ...>   symbol: "ETHUSDT",
      ...>   side: "BUY",
      ...>   type: "LIMIT",
      ...>   quantity: 0.05,
      ...>   price: 2800.0,
      ...>   market_type: "SPOT"
      ...> })

  The prism reads authentication details from configuration:
  - :binance_api_key
  - :binance_api_secret
  """

  use Lux.Prism,
    name: "Binance Order Execution",
    description: "Executes orders on Binance Spot and Futures",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'ETHUSDT')"
        },
        side: %{
          type: :string,
          description: "Order side: BUY or SELL",
          enum: ["BUY", "SELL"]
        },
        type: %{
          type: :string,
          description: "Order type: MARKET, LIMIT, STOP_LOSS, STOP_LOSS_LIMIT, TAKE_PROFIT, TAKE_PROFIT_LIMIT, LIMIT_MAKER",
          enum: ["MARKET", "LIMIT", "STOP_LOSS", "STOP_LOSS_LIMIT", "TAKE_PROFIT", "TAKE_PROFIT_LIMIT", "LIMIT_MAKER"]
        },
        quantity: %{
          type: :number,
          description: "Order quantity"
        },
        price: %{
          type: :number,
          description: "Order price (required for LIMIT orders)"
        },
        timeInForce: %{
          type: :string,
          description: "Time in force (GTC, IOC, FOK). Required for LIMIT orders.",
          enum: ["GTC", "IOC", "FOK"]
        },
        stopPrice: %{
          type: :number,
          description: "Stop price (required for STOP_LOSS and TAKE_PROFIT orders)"
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
      required: ["symbol", "side", "type", "quantity"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        order_result: %{type: :object, description: "Raw response from Binance API"}
      },
      required: ["status", "order_result"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, api_key} <- get_api_key(),
         {:ok, api_secret} <- get_api_secret(),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("binance.client"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("binance_utils.setup"),
         {:ok, result} <- execute_order(api_key, api_secret, input) do
      {:ok, %{status: "success", order_result: result}}
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

  defp execute_order(api_key, api_secret, params) do
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

            order_params = {
                "symbol": params["symbol"],
                "side": params["side"],
                "type": params["type"],
                "quantity": params["quantity"]
            }

            if "price" in params:
                order_params["price"] = params["price"]
            if "timeInForce" in params:
                order_params["timeInForce"] = params["timeInForce"]
            if "stopPrice" in params:
                order_params["stopPrice"] = params["stopPrice"]

            if market_type == "SPOT":
                order_result = client.create_order(**order_params)
            elif market_type == "FUTURES":
                order_result = client.futures_create_order(**order_params)
            else:
                order_result = {"error": f"Unsupported market type: {market_type}"}
            
            order_result
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
