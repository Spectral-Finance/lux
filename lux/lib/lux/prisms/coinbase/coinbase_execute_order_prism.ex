defmodule Lux.Prisms.Coinbase.CoinbaseExecuteOrderPrism do
  @moduledoc """
  A prism that executes orders on Coinbase Advanced Trade.

  ## Example

      iex> Lux.Prisms.Coinbase.CoinbaseExecuteOrderPrism.run(%{
      ...>   product_id: "BTC-USD",
      ...>   side: "BUY",
      ...>   type: "LIMIT",
      ...>   quantity: "0.05",
      ...>   price: "50000.00"
      ...> })

  """

  use Lux.Prism,
    name: "Coinbase Order Execution",
    description: "Executes orders on Coinbase Advanced Trade",
    input_schema: %{
      type: :object,
      properties: %{
        product_id: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'BTC-USD')"
        },
        side: %{
          type: :string,
          description: "Order side: BUY or SELL",
          enum: ["BUY", "SELL"]
        },
        type: %{
          type: :string,
          description: "Order type: MARKET or LIMIT",
          enum: ["MARKET", "LIMIT"]
        },
        quantity: %{
          type: :string,
          description: "Order quantity (base_size)"
        },
        price: %{
          type: :string,
          description: "Order price (required for LIMIT orders)"
        }
      },
      required: ["product_id", "side", "type", "quantity"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        order_result: %{type: :object, description: "Raw response from Coinbase API"}
      },
      required: ["status", "order_result"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, api_key} <- get_api_key(),
         {:ok, api_secret} <- get_api_secret(),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("coinbase.rest"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("coinbase_utils.setup"),
         {:ok, result} <- execute_order(api_key, api_secret, input) do
      {:ok, %{status: "success", order_result: result}}
    else
      {:error, :missing_api_key} ->
        {:error, "Coinbase API Key is not configured"}

      {:error, :missing_api_secret} ->
        {:error, "Coinbase API Secret is not configured"}

      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import required packages: #{error}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_api_key do
    {:ok, Config.coinbase_api_key()}
  rescue
    RuntimeError -> {:error, :missing_api_key}
  end

  defp get_api_secret do
    {:ok, Config.coinbase_api_secret()}
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
        from coinbase_utils.setup import setup
        import traceback
        import uuid

        try:
            client = setup(api_key, api_secret)
            
            client_order_id = str(uuid.uuid4())
            product_id = params["product_id"]
            side = params["side"]
            order_type = params["type"]
            quantity = str(params["quantity"])
            
            order_configuration = {}
            if order_type == "MARKET":
                order_configuration = {
                    "market_market_ioc": {
                        "base_size": quantity
                    }
                }
            elif order_type == "LIMIT":
                price = str(params["price"])
                order_configuration = {
                    "limit_limit_gtc": {
                        "base_size": quantity,
                        "limit_price": price,
                        "post_only": False
                    }
                }
            else:
                raise ValueError(f"Unsupported order type: {order_type}")
                
            order_result = client.create_order(
                client_order_id=client_order_id,
                product_id=product_id,
                side=side,
                order_configuration=order_configuration
            )
            
            if hasattr(order_result, 'to_dict'):
                order_result = order_result.to_dict()
                
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
