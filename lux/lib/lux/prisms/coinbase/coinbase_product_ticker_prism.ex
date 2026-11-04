defmodule Lux.Prisms.Coinbase.CoinbaseProductTickerPrism do
  @moduledoc """
  A prism that fetches the product ticker (market data) from Coinbase Exchange.

  This is a public endpoint and does not require authentication.

  ## Example

      iex> Lux.Prisms.Coinbase.CoinbaseProductTickerPrism.run(%{product_id: "BTC-USD"})
      {:ok,
       %{
         status: "success",
         ticker: %{"product_id" => "BTC-USD", "price" => "50000.00"}
       }}

  See https://docs.cloud.coinbase.com/exchange/reference/exchangerestapi_getproductticker
  """

  use Lux.Prism,
    name: "Coinbase Product Ticker",
    description: "Fetches the product ticker from Coinbase Exchange",
    input_schema: %{
      type: :object,
      properties: %{
        product_id: %{
          type: :string,
          description: "Product ID (e.g. 'BTC-USD', 'ETH-USD')"
        }
      },
      required: ["product_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        ticker: %{type: :object, description: "Raw ticker response from Coinbase Exchange API"}
      },
      required: ["status", "ticker"]
    }

  alias Lux.Coinbase.Client

  def handler(input, _ctx) do
    with {:ok, product_id} <- validate(input) do
      case Client.request(:get, "/products/#{product_id}/ticker", nil, auth?: false) do
        {:ok, ticker} ->
          {:ok, %{status: "success", ticker: ticker}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp validate(%{"product_id" => product_id}) when is_binary(product_id) do
    if String.trim(product_id) != "" do
      {:ok, product_id}
    else
      {:error, "product_id is required and must be a non-empty string"}
    end
  end

  defp validate(_input), do: {:error, "product_id is required and must be a non-empty string"}
end
