defmodule Lux.Prisms.Coinbase.CoinbaseCancelOrderPrism do
  @moduledoc """
  A prism that cancels a specific order on the Coinbase Exchange.

  ## Example

      iex> Lux.Prisms.Coinbase.CoinbaseCancelOrderPrism.run(%{order_id: "order-123"})
      {:ok, %{status: "success", cancelled_order: %{"id" => "order-123"}}}

  The prism reads authentication details from configuration:
  - :coinbase_api_key - Coinbase Exchange API key
  - :coinbase_secret - base64-encoded Coinbase Exchange API secret
  - :coinbase_passphrase - Coinbase Exchange API passphrase

  See https://docs.cloud.coinbase.com/exchange/reference/exchangerestapi_deleteorder
  """

  use Lux.Prism,
    name: "Coinbase Cancel Order",
    description: "Cancels a specific order on Coinbase Exchange",
    input_schema: %{
      type: :object,
      properties: %{
        order_id: %{
          type: :string,
          description: "Order ID to cancel (exchange id or 'client:<client_oid>')"
        }
      },
      required: ["order_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        cancelled_order: %{
          type: :object,
          properties: %{
            id: %{type: :string},
            result: %{type: :object}
          },
          required: ["id", "result"]
        }
      },
      required: ["status", "cancelled_order"]
    }

  alias Lux.Coinbase.Client

  def handler(input, _ctx) do
    with {:ok, order_id} <- validate(input) do
      case Client.request(:delete, "/orders/#{order_id}") do
        {:ok, result} ->
          {:ok, %{status: "success", cancelled_order: %{"id" => order_id, "result" => result}}}

        {:error, %{"status" => 401}} ->
          {:error, %{code: :unauthorized, reason: "invalid Coinbase API credentials"}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp validate(%{"order_id" => order_id}) when is_binary(order_id) do
    if String.trim(order_id) != "" do
      {:ok, order_id}
    else
      {:error, "order_id is required and must be a non-empty string"}
    end
  end

  defp validate(_input), do: {:error, "order_id is required and must be a non-empty string"}
end
