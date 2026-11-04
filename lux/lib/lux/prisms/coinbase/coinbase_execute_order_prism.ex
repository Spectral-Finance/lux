defmodule Lux.Prisms.Coinbase.CoinbaseExecuteOrderPrism do
  @moduledoc """
  A prism that places orders on the Coinbase Exchange.

  ## Example

      # Limit buy order
      iex> Lux.Prisms.Coinbase.CoinbaseExecuteOrderPrism.run(%{
      ...>   product_id: "BTC-USD",
      ...>   side: "buy",
      ...>   type: "limit",
      ...>   size: "0.01",
      ...>   price: "50000"
      ...> })
      {:ok,
       %{
         status: "success",
         order: %{"id" => "order-123", "product_id" => "BTC-USD"}
       }}

  The prism reads authentication details from configuration:
  - :coinbase_api_key - Coinbase Exchange API key
  - :coinbase_secret - base64-encoded Coinbase Exchange API secret
  - :coinbase_passphrase - Coinbase Exchange API passphrase

  See https://docs.cloud.coinbase.com/exchange/reference/exchangerestapi_postorder
  """

  use Lux.Prism,
    name: "Coinbase Execute Order",
    description: "Places an order on Coinbase Exchange",
    input_schema: %{
      type: :object,
      properties: %{
        product_id: %{
          type: :string,
          description: "Product ID (e.g. 'BTC-USD', 'ETH-USD')"
        },
        side: %{
          type: :string,
          description: "'buy' or 'sell'",
          enum: ["buy", "sell"]
        },
        type: %{
          type: :string,
          description: "Order type: 'limit' or 'market'",
          enum: ["limit", "market"]
        },
        size: %{
          type: :number,
          description: "Order size in base currency (must be > 0)"
        },
        price: %{
          type: :number,
          description: "Limit price (required for limit orders, must be > 0)"
        },
        client_oid: %{
          type: :string,
          description: "Optional client-assigned order id"
        }
      },
      required: ["product_id", "side", "type", "size"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        order: %{type: :object, description: "Raw response from Coinbase Exchange API"}
      },
      required: ["status", "order"]
    }

  alias Lux.Coinbase.Client

  def handler(input, _ctx) do
    with {:ok, params} <- validate(input) do
      case Client.request(:post, "/orders", build_body(params)) do
        {:ok, order} ->
          {:ok, %{status: "success", order: order}}

        {:error, %{"status" => 401}} ->
          {:error, %{code: :unauthorized, reason: "invalid Coinbase API credentials"}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp validate(%{"product_id" => product_id} = params) when is_binary(product_id) do
    if String.trim(product_id) != "" do
      validate_side(params)
    else
      {:error, "product_id is required and must be a non-empty string"}
    end
  end

  defp validate(_input), do: {:error, "product_id is required and must be a non-empty string"}

  defp validate_side(%{"side" => side} = params) when side in ["buy", "sell"] do
    validate_type(params)
  end

  defp validate_side(_input), do: {:error, "side must be 'buy' or 'sell'"}

  defp validate_type(%{"type" => type} = params) when type in ["limit", "market"] do
    validate_size(params)
  end

  defp validate_type(_input), do: {:error, "type must be 'limit' or 'market'"}

  defp validate_size(%{"size" => size} = params) when is_number(size) and size > 0 do
    validate_limit_price(params)
  end

  defp validate_size(_input), do: {:error, "size must be a number greater than 0"}

  defp validate_limit_price(%{"type" => "limit", "price" => price} = params)
       when is_number(price) and price > 0 do
    {:ok, params}
  end

  defp validate_limit_price(%{"type" => "limit"}) do
    {:error, "price is required and must be a number greater than 0 for limit orders"}
  end

  defp validate_limit_price(params), do: {:ok, params}

  defp build_body(%{
           "product_id" => product_id,
           "side" => side,
           "type" => type,
           "size" => size
         } = params) do
    body = %{
      product_id: product_id,
      side: side,
      type: type,
      size: size
    }

    body =
      if params["price"] != nil do
        Map.put(body, :price, params["price"])
      else
        body
      end

    body =
      if params["client_oid"] != nil do
        Map.put(body, :client_oid, params["client_oid"])
      else
        body
      end

    body
  end
end
