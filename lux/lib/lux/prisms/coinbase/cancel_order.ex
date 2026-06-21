defmodule Lux.Prisms.Coinbase.CancelOrder do
  @moduledoc """
  A prism for canceling orders on Coinbase Advanced Trade.
  """

  use Lux.Prism,
    name: "Cancel Coinbase Order",
    description: "Cancels an open order on Coinbase",
    input_schema: %{
      type: :object,
      properties: %{
        order_ids: %{
          type: :array,
          items: %{type: :string},
          description: "List of Coinbase Order IDs to cancel"
        }
      },
      required: ["order_ids"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        results: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              order_id: %{type: :string},
              success: %{type: :boolean}
            }
          }
        }
      },
      required: ["results"]
    }

  alias Lux.Integrations.Coinbase.Client
  require Logger

  @impl true
  def handler(params, _agent) do
    api_params = %{
      "order_ids" => params.order_ids
    }

    case Client.request(:post, "/api/v3/brokerage/orders/batch_cancel", signed: true, json: api_params) do
      {:ok, %{"results" => results}} ->
        Logger.info("Successfully processed batch cancel for Coinbase orders")
        
        formatted_results = Enum.map(results, fn r ->
          %{
            order_id: r["order_id"],
            success: r["success"]
          }
        end)
        
        {:ok, %{results: formatted_results}}

      {:error, {status, body}} ->
        error = "Coinbase API Error (#{status}): #{inspect(body)}"
        Logger.error("Failed to cancel orders: #{error}")
        {:error, error}
        
      {:error, error} ->
        Logger.error("Failed to cancel orders: #{inspect(error)}")
        {:error, inspect(error)}
    end
  end
end
