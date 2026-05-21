defmodule Lux.Prisms.Coinbase.CoinbaseOpenOrdersPrism do
  @moduledoc """
  A prism that fetches open orders on Coinbase.

  ## Example

      iex> Lux.Prisms.Coinbase.CoinbaseOpenOrdersPrism.run(%{
      ...>   product_id: "BTC-USD"
      ...> })

  """

  use Lux.Prism,
    name: "Coinbase Open Orders",
    description: "Fetches open orders on Coinbase Advanced Trade",
    input_schema: %{
      type: :object,
      properties: %{
        product_id: %{
          type: :string,
          description: "Optional product ID to filter by (e.g., 'BTC-USD')"
        },
        limit: %{
          type: :integer,
          description: "Maximum number of orders to return",
          default: 100
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        orders: %{type: :object, description: "Raw response from Coinbase API"}
      },
      required: ["status", "orders"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, api_key} <- get_api_key(),
         {:ok, api_secret} <- get_api_secret(),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("coinbase.rest"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("coinbase_utils.setup"),
         {:ok, result} <- get_open_orders(api_key, api_secret, input) do
      {:ok, %{status: "success", orders: result}}
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

  defp get_open_orders(api_key, api_secret, params) do
    python_result =
      python variables: %{
               api_key: api_key,
               api_secret: api_secret,
               params: params
             } do
        ~PY"""
        from coinbase_utils.setup import setup
        import traceback

        try:
            client = setup(api_key, api_secret)
            
            kwargs = {
                "order_status": ["OPEN", "PENDING"]
            }
            if "product_id" in params:
                kwargs["product_id"] = params["product_id"]
            if "limit" in params:
                kwargs["limit"] = params["limit"]
                
            orders_result = client.list_orders(**kwargs)
            
            if hasattr(orders_result, 'to_dict'):
                orders_result = orders_result.to_dict()
                
            orders_result
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
