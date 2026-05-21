defmodule Lux.Prisms.Coinbase.CoinbaseMarketDataPrism do
  @moduledoc """
  A prism that fetches market data (order book) on Coinbase.

  ## Example

      iex> Lux.Prisms.Coinbase.CoinbaseMarketDataPrism.run(%{
      ...>   product_id: "BTC-USD"
      ...> })

  """

  use Lux.Prism,
    name: "Coinbase Market Data",
    description: "Fetches market data (product book) on Coinbase Advanced Trade",
    input_schema: %{
      type: :object,
      properties: %{
        product_id: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'BTC-USD')"
        },
        limit: %{
          type: :integer,
          description: "Number of bids/asks to return",
          default: 100
        }
      },
      required: ["product_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        market_data: %{type: :object, description: "Raw response from Coinbase API"}
      },
      required: ["status", "market_data"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, api_key} <- get_api_key(),
         {:ok, api_secret} <- get_api_secret(),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("coinbase.rest"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("coinbase_utils.setup"),
         {:ok, result} <- get_market_data(api_key, api_secret, input) do
      {:ok, %{status: "success", market_data: result}}
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

  defp get_market_data(api_key, api_secret, params) do
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
            
            product_id = params["product_id"]
            limit = params.get("limit", 100)
                
            book_result = client.get_product_book(product_id=product_id, limit=limit)
            
            if hasattr(book_result, 'to_dict'):
                book_result = book_result.to_dict()
                
            book_result
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
