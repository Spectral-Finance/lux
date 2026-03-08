defmodule Lux.Prisms.Binance.FuturesOrder do
  @moduledoc """
  A prism for managing futures orders on Binance.
  """

  use Lux.Prism,
    name: "Binance Futures Order",
    description: "Place, cancel, and manage Binance futures orders and settings",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["place", "cancel", "status", "set_leverage", "set_margin_type"]},
        symbol: %{type: :string},
        side: %{type: :string, enum: ["BUY", "SELL"]},
        type: %{type: :string, enum: ["LIMIT", "MARKET", "STOP", "STOP_MARKET", "TAKE_PROFIT", "TAKE_PROFIT_MARKET", "TRAILING_STOP_MARKET"]},
        quantity: %{type: :string},
        price: %{type: :string},
        time_in_force: %{type: :string, enum: ["GTC", "IOC", "FOK", "GTX"]},
        order_id: %{type: :integer},
        stop_price: %{type: :string},
        leverage: %{type: :integer},
        margin_type: %{type: :string, enum: ["ISOLATED", "CROSSED"]},
        position_side: %{type: :string, enum: ["BOTH", "LONG", "SHORT"]},
        reduce_only: %{type: :boolean}
      },
      required: ["action", "symbol"]
    },
    output_schema: %{
      type: :object,
      properties: %{order_id: %{type: :integer}, symbol: %{type: :string}, status: %{type: :string}, leverage: %{type: :integer}, margin_type: %{type: :string}}
    }

  alias Lux.Integrations.Binance.Client

  def handler(params, agent) do
    action = to_string(params[:action] || params["action"])
    _agent_name = get_in(agent, [:agent, :name]) || get_in(agent, [:name]) || "Unknown"
    plug = params[:plug] || params["plug"]
    opts = %{signed: true, futures: true}
    opts = if plug, do: Map.put(opts, :plug, plug), else: opts

    case action do
      "place" -> place(params, opts)
      "cancel" -> cancel(params, opts)
      "status" -> status(params, opts)
      "set_leverage" -> set_leverage(params, opts)
      "set_margin_type" -> set_margin_type(params, opts)
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
    |> maybe_put(:positionSide, p[:position_side] || p["position_side"])
    |> maybe_put(:reduceOnly, p[:reduce_only] || p["reduce_only"])

    case Client.request(:post, "/fapi/v1/order", Map.put(opts, :params, order)) do
      {:ok, d} -> {:ok, fmt(d)}
      {:error, e} -> {:error, e}
    end
  end

  defp cancel(p, opts) do
    params = %{symbol: to_s(p, :symbol), orderId: p[:order_id] || p["order_id"]}
    case Client.request(:delete, "/fapi/v1/order", Map.put(opts, :params, params)) do
      {:ok, d} -> {:ok, fmt(d)}
      {:error, e} -> {:error, e}
    end
  end

  defp status(p, opts) do
    params = %{symbol: to_s(p, :symbol), orderId: p[:order_id] || p["order_id"]}
    case Client.request(:get, "/fapi/v1/order", Map.put(opts, :params, params)) do
      {:ok, d} -> {:ok, fmt(d)}
      {:error, e} -> {:error, e}
    end
  end

  defp set_leverage(p, opts) do
    params = %{symbol: to_s(p, :symbol), leverage: p[:leverage] || p["leverage"]}
    case Client.request(:post, "/fapi/v1/leverage", Map.put(opts, :params, params)) do
      {:ok, d} -> {:ok, %{symbol: d["symbol"], leverage: d["leverage"], max_notional_value: d["maxNotionalValue"]}}
      {:error, e} -> {:error, e}
    end
  end

  defp set_margin_type(p, opts) do
    symbol = to_s(p, :symbol)
    margin_type = to_string(p[:margin_type] || p["margin_type"])
    params = %{symbol: symbol, marginType: margin_type}
    case Client.request(:post, "/fapi/v1/marginType", Map.put(opts, :params, params)) do
      {:ok, _} -> {:ok, %{symbol: symbol, margin_type: margin_type}}
      {:error, e} -> {:error, e}
    end
  end

  defp fmt(d) do
    %{
      order_id: d["orderId"], symbol: d["symbol"], status: d["status"],
      side: d["side"], type: d["type"], price: d["price"],
      quantity: d["origQty"], executed_qty: d["executedQty"],
      position_side: d["positionSide"], time: d["updateTime"] || d["time"]
    }
  end

  defp to_s(p, k), do: to_string(p[k] || p[Atom.to_string(k)])
  defp maybe_put(m, _k, nil), do: m
  defp maybe_put(m, k, v), do: Map.put(m, k, v)
end
