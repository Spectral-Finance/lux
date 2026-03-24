defmodule Lux.Prisms.Coinbase.CoinbaseMarketDataPrism do
  @moduledoc """
  A prism that fetches market data from the Coinbase Exchange.

  ## Example

      # Get product ticker
      iex> Lux.Prisms.Coinbase.CoinbaseMarketDataPrism.run(%{
      ...>   product_id: "BTC-USD",
      ...>   data_type: "ticker"
      ...> })
      {:ok,
       %{
         status: "success",
         ticker: %{
           "trade_id" => 123456,
           "price" => "50000.00",
           "bid" => "49999.00",
           "ask" => "50001.00",
           "volume" => "1000.5"
         }
       }}

      # Get order book
      iex> Lux.Prisms.Coinbase.CoinbaseMarketDataPrism.run(%{
      ...>   product_id: "BTC-USD",
      ...>   data_type: "orderbook",
      ...>   level: 2
      ...> })

      # Get recent trades
      iex> Lux.Prisms.Coinbase.CoinbaseMarketDataPrism.run(%{
      ...>   product_id: "BTC-USD",
      ...>   data_type: "trades"
      ...> })

      # Get historical candles
      iex> Lux.Prisms.Coinbase.CoinbaseMarketDataPrism.run(%{
      ...>   product_id: "BTC-USD",
      ...>   data_type: "candles",
      ...>   granularity: 3600
      ...> })

  This endpoint does not require authentication for basic market data.
  """

  use Lux.Prism,
    name: "Coinbase Market Data",
    description: "Fetches market data from Coinbase Exchange",
    input_schema: %{
      type: :object,
      properties: %{
        product_id: %{
          type: :string,
          description: "Trading pair (e.g., 'BTC-USD', 'ETH-USD')"
        },
        data_type: %{
          type: :string,
          description: "Type of market data to fetch",
          enum: ["ticker", "orderbook", "trades", "candles", "product"]
        },
        level: %{
          type: :integer,
          description: "Order book level (1, 2, or 3)",
          minimum: 1,
          maximum: 3,
          default: 1
        },
        granularity: %{
          type: :integer,
          description: "Candle granularity in seconds (60, 300, 900, 3600, 21600, 86400)",
          enum: [60, 300, 900, 3600, 21600, 86400]
        }
      },
      required: ["product_id", "data_type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        data: %{type: :object, description: "Market data response"},
        error: %{type: :string}
      },
      required: ["status"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, api_key} <- get_optional_api_key(),
         {:ok, api_secret} <- get_optional_api_secret(),
         {:ok, passphrase} <- get_optional_passphrase(),
         {:ok, base_url} <- {:ok, Config.coinbase_api_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("coinbase_utils.setup"),
         {:ok, result} <- fetch_market_data(api_key, api_secret, passphrase, base_url, input) do
      {:ok, %{status: "success", data: result}}
    else
      {:error, reason} when is_binary(reason) ->
        {:error, reason}

      {:error, reason} ->
        {:error, "Failed to fetch market data: #{inspect(reason)}"}
    end
  end

  defp get_optional_api_key do
    {:ok, Config.coinbase_api_key()}
  rescue
    RuntimeError -> {:ok, nil}
  end

  defp get_optional_api_secret do
    {:ok, Config.coinbase_api_secret()}
  rescue
    RuntimeError -> {:ok, nil}
  end

  defp get_optional_passphrase do
    {:ok, Config.coinbase_api_passphrase()}
  rescue
    RuntimeError -> {:ok, nil}
  end

  defp fetch_market_data(api_key, api_secret, passphrase, base_url, params) do
    python_result =
      python variables: %{
               api_key: api_key,
               api_secret: api_secret,
               passphrase: passphrase,
               base_url: base_url,
               params: params
             } do
        ~PY"""
        from coinbase_utils.setup import setup, CoinbaseRestClient
        import requests

        # Use default client for public endpoints
        if api_key and api_secret and passphrase:
            rest_client, _ = setup(api_key, api_secret, passphrase, base_url)
        else:
            rest_client = CoinbaseRestClient("", "", "", base_url)

        product_id = params.get("product_id")
        data_type = params.get("data_type")

        try:
            if data_type == "ticker":
                result = rest_client.get_product_ticker(product_id)
            elif data_type == "orderbook":
                level = params.get("level", 1)
                result = rest_client.get_product_order_book(product_id, level)
            elif data_type == "trades":
                result = rest_client.get_product_trades(product_id)
            elif data_type == "candles":
                granularity = params.get("granularity", 86400)
                result = rest_client.get_candles(product_id, granularity)
            elif data_type == "product":
                result = rest_client.get_product(product_id)
            else:
                result = {"error": f"Unknown data type: {data_type}"}

            result
        except Exception as e:
            {"error": str(e)}
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result -> {:ok, result}
    end
  end
end