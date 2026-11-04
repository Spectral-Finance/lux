defmodule Lux.Prisms.Coinbase.CoinbaseOpenOrdersPrism do
  @moduledoc """
  A prism that lists open orders on the Coinbase Exchange.

  ## Example

      iex> Lux.Prisms.Coinbase.CoinbaseOpenOrdersPrism.run(%{product_id: "BTC-USD"})
      {:ok, %{status: "success", orders: [%{"id" => "order-123"}]}}

  The prism reads authentication details from configuration:
  - :coinbase_api_key - Coinbase Exchange API key
  - :coinbase_secret - base64-encoded Coinbase Exchange API secret
  - :coinbase_passphrase - Coinbase Exchange API passphrase

  See https://docs.cloud.coinbase.com/exchange/reference/exchangerestapi_getorders
  """

  use Lux.Prism,
    name: "Coinbase Open Orders",
    description: "Lists open orders on Coinbase Exchange",
    input_schema: %{
      type: :object,
      properties: %{
        product_id: %{
          type: :string,
          description: "Optional product ID filter (e.g. 'BTC-USD')"
        },
        status: %{
          type: :string,
          description: "Order status filter",
          enum: ["open", "pending", "active"],
          default: "open"
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        orders: %{type: :object, description: "List of open orders from Coinbase Exchange API"}
      },
      required: ["status", "orders"]
    }

  alias Lux.Coinbase.Client

  def handler(input, _ctx) do
    with {:ok, params} <- validate(input) do
      path = build_path(params)

      case Client.request(:get, path) do
        {:ok, orders} ->
          {:ok, %{status: "success", orders: orders}}

        {:error, %{"status" => 401}} ->
          {:error, %{code: :unauthorized, reason: "invalid Coinbase API credentials"}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp validate(input) when is_map(input) do
    status = Map.get(input, "status", "open")

    if status in ["open", "pending", "active"] do
      {:ok, input}
    else
      {:error, "status must be 'open', 'pending' or 'active'"}
    end
  end

  defp validate(_input), do: {:error, "input must be a map"}

  defp build_path(%{"product_id" => product_id} = params) when is_binary(product_id) and product_id != "" do
    "/orders?status=#{Map.get(params, "status", "open")}&product_id=#{product_id}"
  end

  defp build_path(params) do
    "/orders?status=#{Map.get(params, "status", "open")}"
  end
end
