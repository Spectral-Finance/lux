defmodule Lux.Prisms.Coinbase.CancelOrder do
  @moduledoc """
  A prism for cancelling orders on Coinbase Advanced Trade.
  """

  use Lux.Prism,
    name: "Coinbase Cancel Order",
    description: "Cancels active trading orders on Coinbase Advanced Trade",
    input_schema: %{
      type: :object,
      properties: %{
        order_ids: %{
          type: :array,
          items: %{type: :string},
          description: "List of Order IDs to cancel"
        }
      },
      required: ["order_ids"]
    }

  alias Lux.Integrations.Coinbase.Client

  @impl true
  def handler(params, _ctx) do
    path = "/api/v3/brokerage/orders/batch_cancel"

    api_params = %{
      "order_ids" => params.order_ids
    }

    case Client.request(:post, path, signed: true, json: api_params) do
      {:ok, response} ->
        {:ok, response}

      {:error, error} ->
        {:error, inspect(error)}
    end
  end
end
