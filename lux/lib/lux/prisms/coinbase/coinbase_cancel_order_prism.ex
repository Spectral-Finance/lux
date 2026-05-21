defmodule Lux.Prisms.Coinbase.CoinbaseCancelOrderPrism do
  @moduledoc """
  A prism that cancels an order on Coinbase Advanced Trade.

  ## Example

      iex> Lux.Prisms.Coinbase.CoinbaseCancelOrderPrism.run(%{
      ...>   order_ids: ["abc-123", "def-456"]
      ...> })

  """

  use Lux.Prism,
    name: "Coinbase Cancel Order",
    description: "Cancels orders on Coinbase Advanced Trade",
    input_schema: %{
      type: :object,
      properties: %{
        order_ids: %{
          type: :array,
          items: %{type: :string},
          description: "List of order IDs to cancel"
        }
      },
      required: ["order_ids"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        cancel_result: %{type: :object, description: "Raw response from Coinbase API"}
      },
      required: ["status", "cancel_result"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, api_key} <- get_api_key(),
         {:ok, api_secret} <- get_api_secret(),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("coinbase.rest"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("coinbase_utils.setup"),
         {:ok, result} <- cancel_order(api_key, api_secret, input) do
      {:ok, %{status: "success", cancel_result: result}}
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

  defp cancel_order(api_key, api_secret, params) do
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
            
            order_ids = params["order_ids"]
            
            cancel_result = client.cancel_orders(order_ids=order_ids)
            
            if hasattr(cancel_result, 'to_dict'):
                cancel_result = cancel_result.to_dict()
                
            cancel_result
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
