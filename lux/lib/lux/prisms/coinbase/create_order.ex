defmodule Lux.Prisms.Coinbase.CreateOrder do
  @moduledoc """
  Prism for creating orders on Coinbase (market, limit, stop-limit).
  """

  use Lux.Prism,
    name: "Create Coinbase Order",
    description: "Places an order on Coinbase (market, limit, or stop-limit)",
    input_schema: %{
      type: :object,
      properties: %{
        product_id: %{type: :string, description: "Trading pair (e.g. BTC-USD)"},
        side: %{type: :string, description: "BUY or SELL", enum: ["BUY", "SELL"]},
        order_type: %{type: :string, description: "market, limit, or stop_limit", enum: ["market", "limit", "stop_limit"]},
        amount: %{type: :string, description: "Quote amount for market buy orders"},
        base_size: %{type: :string, description: "Base amount for limit/sell orders"},
        limit_price: %{type: :string, description: "Limit price"},
        stop_price: %{type: :string, description: "Stop trigger price"},
        stop_direction: %{type: :string, description: "STOP_DIRECTION_STOP_UP or STOP_DIRECTION_STOP_DOWN"}
      },
      required: ["product_id", "side", "order_type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{type: :boolean}, order_id: %{type: :string}, product_id: %{type: :string}, side: %{type: :string}
      },
      required: ["success"]
    }

  alias Lux.Integrations.Coinbase.Client
  require Logger

  def handler(params, agent) do
    with {:ok, product_id} <- validate_param(params, :product_id),
         {:ok, side} <- validate_param(params, :side),
         {:ok, order_type} <- validate_param(params, :order_type) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} creating #{order_type} #{side} order for #{product_id}")

      body = %{
        client_order_id: :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower),
        product_id: product_id,
        side: side,
        order_configuration: build_order_config(order_type, params)
      }

      case Client.request(:post, "/orders", %{json: body}) do
        {:ok, %{"success" => true, "order_id" => order_id}} ->
          {:ok, %{success: true, order_id: order_id, product_id: product_id, side: side}}
        {:ok, %{"success" => false, "error_response" => %{"message" => msg}}} ->
          {:error, msg}
        {:error, error} -> {:error, error}
      end
    end
  end

  defp build_order_config("market", params) do
    cond do
      params[:amount] || params["amount"] -> %{"market_market_ioc" => %{"quote_size" => params[:amount] || params["amount"]}}
      params[:base_size] || params["base_size"] -> %{"market_market_ioc" => %{"base_size" => params[:base_size] || params["base_size"]}}
      true -> %{"market_market_ioc" => %{}}
    end
  end

  defp build_order_config("limit", params) do
    %{"limit_limit_gtc" => %{
      "base_size" => params[:base_size] || params["base_size"],
      "limit_price" => params[:limit_price] || params["limit_price"],
      "post_only" => false
    }}
  end

  defp build_order_config("stop_limit", params) do
    %{"stop_limit_stop_limit_gtc" => %{
      "base_size" => params[:base_size] || params["base_size"],
      "limit_price" => params[:limit_price] || params["limit_price"],
      "stop_price" => params[:stop_price] || params["stop_price"],
      "stop_direction" => params[:stop_direction] || params["stop_direction"]
    }}
  end

  defp validate_param(params, key) do
    case params[key] || params[to_string(key)] do
      nil -> {:error, "Missing required parameter: #{key}"}
      "" -> {:error, "Missing required parameter: #{key}"}
      v when is_binary(v) -> {:ok, v}
      _ -> {:error, "Invalid #{key}"}
    end
  end
end
