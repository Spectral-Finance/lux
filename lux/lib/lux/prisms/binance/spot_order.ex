defmodule Lux.Prisms.Binance.SpotOrder do
  @moduledoc """
  A prism for managing spot orders on Binance.
  """

  use Lux.Prism,
    name: "Binance Spot Order",
    description: "Place, cancel, and check status of Binance spot orders",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["place", "cancel", "status"]},
        symbol: %{type: :string},
        side: %{type: :string, enum: ["BUY", "SELL"]},
        type: %{type: :string, enum: ["LIMIT", "MARKET", "STOP_LOSS_LIMIT", "TAKE_PROFIT_LIMIT"]},
        quantity: %{type: :string},
        price: %{type: :string},
        time_in_force: %{type: :string, enum: ["GTC", "IOC", "FOK"]},
        order_id: %{type: :integer},
        stop_price: %{type: :string}
      },
      required: ["action", "symbol"]
    },
    output_schema: %{
      type: :object,
      properties: %{order_id: %{type: :integer}, symbol: %{type: :string}, status: %{type: :string}},
      required: ["order_id", "status"]
    }

  alias Lux.Integrations.Binance.Client

  def handler(params, agent) do
    action = to_string(params[:action] || params["action"])
    _agent_name = get_in(agent, [:agent, :name]) || get_in(agent, [:name]) || "Unknown"
    plug = params[:plug] || params["plug"]
    opts = %{signed: true}
    opts = if plug, do: Map.put(opts, :plug, plug), else: opts
    opts = if params[:api_key], do: Map.put(opts, :api_key, params[:api_key]), else: opts
    opts = if params[:secret_key], do: Map.put(opts, :secret_key, params[:secret_key]), else: opts

    case action do
      "place" -> place(params, opts)
      "cancel" -> cancel(params, opts)
      "status" -> status(params, opts)
      _ -> {:error, "Unknown action: #{action}"}
    end
  end

  defp place(p, opts) do
    order = %{
      symbol: to_s(p, :symbol), side: to_s(p, :side),
      type: to_s(p, :type), quantity: to_s(p, :quantity)
    }
    |> maybe_put(:price, p[:price] || p["price"])
    |> maybe_put(:timeInForce, p[:time_in_force] || p["time_in_force"])
    |> maybe_put(:stopPrice, p[:stop_price] || p["stop_price"])

    case Client.request(:post, "/api/v3/order", Map.put(opts, :params, order)) do
      {:ok, d} -> {:ok, fmt(d)}
      {:error, e} -> {:error, e}
    end
  end

  defp cancel(p, opts) do
    params = %{symbol: to_s(p, :symbol), orderId: p[:order_id] || p["order_id"]}
    case Client.request(:delete, "/api/v3/order", Map.put(opts, :params, params)) do
      {:ok, d} -> {:ok, fmt(d)}
      {:error, e} -> {:error, e}
    end
  end

  defp status(p, opts) do
    params = %{symbol: to_s(p, :symbol), orderId: p[:order_id] || p["order_id"]}
    case Client.request(:get, "/api/v3/order", Map.put(opts, :params, params)) do
      {:ok, d} -> {:ok, fmt(d)}
      {:error, e} -> {:error, e}
    end
  end

  defp fmt(d) do
    %{
      order_id: d["orderId"], symbol: d["symbol"], status: d["status"],
      side: d["side"], type: d["type"], price: d["price"],
      quantity: d["origQty"], executed_qty: d["executedQty"],
      time: d["transactTime"] || d["time"]
    }
  end

  defp to_s(p, k), do: to_string(p[k] || p[Atom.to_string(k)])
  defp maybe_put(m, _k, nil), do: m
  defp maybe_put(m, k, v), do: Map.put(m, k, v)
end
