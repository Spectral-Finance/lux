defmodule Lux.Integrations.Hyperliquid.Perps do
  @moduledoc """
  Perpetual trading position, margin, PnL, and risk-control helpers for Hyperliquid.
  """

  @default_policy %{
    max_leverage: 5.0,
    max_position_notional_pct: 0.25,
    min_liquidation_buffer_pct: 0.12,
    max_margin_usage_pct: 0.65,
    max_order_notional_pct: 0.10
  }

  @doc "Normalizes Hyperliquid asset positions."
  @spec positions(map()) :: [map()]
  def positions(user_state) when is_map(user_state) do
    user_state
    |> value(:assetPositions, [])
    |> Enum.map(&normalize_position/1)
    |> Enum.reject(&(&1.size == 0.0))
  end

  @doc "Summarizes account margin and leverage."
  @spec margin_summary(map()) :: map()
  def margin_summary(user_state) when is_map(user_state) do
    margin = value(user_state, :crossMarginSummary, value(user_state, :marginSummary, %{}))
    account_value = numeric(value(margin, :accountValue, 0))
    total_notional = numeric(value(margin, :totalNtlPos, 0))
    margin_used = numeric(value(margin, :totalMarginUsed, 0))
    maintenance = numeric(value(user_state, :crossMaintenanceMarginUsed, 0))

    %{
      account_value: account_value,
      total_notional: total_notional,
      margin_used: margin_used,
      maintenance_margin_used: maintenance,
      withdrawable: numeric(value(user_state, :withdrawable, 0)),
      leverage: ratio(total_notional, account_value),
      margin_usage: ratio(margin_used, account_value),
      maintenance_usage: ratio(maintenance, account_value)
    }
  end

  @doc "Builds a validated Hyperliquid order request for the existing execution prism."
  @spec order_request(map()) :: {:ok, map()} | {:error, [String.t()]}
  def order_request(params) when is_map(params) do
    request = %{
      coin: value(params, :coin),
      is_buy: value(params, :is_buy),
      sz: numeric(value(params, :sz, value(params, :size, 0))),
      limit_px: numeric(value(params, :limit_px, value(params, :price, 0))),
      order_type: value(params, :order_type, %{limit: %{tif: "Gtc"}}),
      reduce_only: value(params, :reduce_only, false)
    }

    errors =
      []
      |> maybe_add(not is_binary(request.coin) or request.coin == "", "coin is required")
      |> maybe_add(not is_boolean(request.is_buy), "is_buy must be boolean")
      |> maybe_add(request.sz <= 0, "size must be positive")
      |> maybe_add(request.limit_px <= 0, "limit price must be positive")

    if errors == [], do: {:ok, request}, else: {:error, Enum.reverse(errors)}
  end

  @doc "Returns PnL totals from current positions and fills."
  @spec pnl_tracking(map(), [map()]) :: map()
  def pnl_tracking(user_state, fills \\ []) do
    open_positions = positions(user_state)

    realized =
      fills
      |> Enum.map(&numeric(value(&1, :closedPnl, 0)))
      |> Enum.sum()

    unrealized =
      open_positions
      |> Enum.map(& &1.unrealized_pnl)
      |> Enum.sum()

    %{
      open_positions: open_positions,
      realized_pnl: realized,
      unrealized_pnl: unrealized,
      total_pnl: realized + unrealized
    }
  end

  @doc "Calculates liquidation buffers and alerts for open positions."
  @spec liquidation_monitor(map(), map(), keyword() | map()) :: map()
  def liquidation_monitor(user_state, mids, opts \\ []) do
    policy = policy(opts)

    monitored =
      user_state
      |> positions()
      |> Enum.map(fn position ->
        mark = numeric(value(mids, position.coin, position.mark_price))
        buffer = liquidation_buffer(position, mark)

        alert =
          not is_nil(position.liquidation_price) and buffer < policy.min_liquidation_buffer_pct

        position
        |> Map.put(:mark_price, mark)
        |> Map.put(:liquidation_buffer_pct, buffer)
        |> Map.put(:liquidation_alert, alert)
      end)

    %{
      status:
        if(Enum.any?(monitored, & &1.liquidation_alert), do: :attention_required, else: :healthy),
      positions: monitored,
      alerts:
        monitored
        |> Enum.filter(& &1.liquidation_alert)
        |> Enum.map(&"#{&1.coin} liquidation buffer below policy")
    }
  end

  @doc "Checks a proposed order against margin, leverage, and liquidation policy."
  @spec risk_check(map(), map(), map(), keyword() | map()) :: {:ok, map()} | {:error, map()}
  def risk_check(user_state, mids, order, opts \\ []) do
    with {:ok, request} <- order_request(order) do
      policy = policy(opts)
      margin = margin_summary(user_state)
      mark = numeric(value(mids, request.coin, request.limit_px))
      order_notional = request.sz * mark

      leverage_after =
        ratio(
          margin.total_notional + signed_notional(request, order_notional),
          margin.account_value
        )

      order_pct = ratio(order_notional, margin.account_value)

      margin_usage_after =
        margin.margin_usage +
          ratio(initial_margin(order_notional, leverage_after), margin.account_value)

      liquidation = liquidation_monitor(user_state, mids, policy: policy)

      alerts =
        []
        |> maybe_add(leverage_after > policy.max_leverage, "projected leverage exceeds policy")
        |> maybe_add(order_pct > policy.max_order_notional_pct, "order notional exceeds policy")
        |> maybe_add(
          margin_usage_after > policy.max_margin_usage_pct,
          "projected margin usage exceeds policy"
        )
        |> maybe_add(
          liquidation.status != :healthy,
          "existing position liquidation buffer is below policy"
        )

      decision = %{
        order: request,
        order_notional: order_notional,
        account_value: margin.account_value,
        projected_leverage: leverage_after,
        projected_margin_usage: margin_usage_after,
        liquidation: liquidation,
        alerts: Enum.reverse(alerts)
      }

      if decision.alerts == [] do
        {:ok, Map.put(decision, :decision, :approved)}
      else
        {:error, Map.put(decision, :decision, :blocked)}
      end
    end
  end

  @doc "Builds a compact trading dashboard payload."
  @spec dashboard(map(), keyword() | map()) :: map()
  def dashboard(input, opts \\ []) do
    user_state = value(input, :user_state, %{})
    mids = value(input, :mids, %{})
    fills = value(input, :fills, [])
    orders = value(input, :open_orders, [])

    %{
      margin: margin_summary(user_state),
      pnl: pnl_tracking(user_state, fills),
      liquidation: liquidation_monitor(user_state, mids, opts),
      open_orders: orders,
      open_order_count: length(orders)
    }
  end

  defp normalize_position(%{"position" => position}), do: normalize_position(position)
  defp normalize_position(%{position: position}), do: normalize_position(position)

  defp normalize_position(position) do
    size = numeric(value(position, :szi, value(position, :size, 0)))
    entry = nullable_numeric(value(position, :entryPx))
    liquidation = nullable_numeric(value(position, :liquidationPx))

    %{
      coin: value(position, :coin),
      size: size,
      side: if(size >= 0, do: :long, else: :short),
      entry_price: entry,
      position_value: numeric(value(position, :positionValue, 0)),
      unrealized_pnl: numeric(value(position, :unrealizedPnl, 0)),
      return_on_equity: numeric(value(position, :returnOnEquity, 0)),
      leverage: leverage_value(value(position, :leverage)),
      liquidation_price: liquidation,
      margin_used: numeric(value(position, :marginUsed, 0)),
      mark_price: numeric(value(position, :markPx, entry || 0))
    }
  end

  defp liquidation_buffer(%{liquidation_price: nil}, _mark), do: 1.0
  defp liquidation_buffer(_position, mark) when mark <= 0, do: 0.0
  defp liquidation_buffer(%{liquidation_price: liq}, mark), do: abs(mark - liq) / mark

  defp signed_notional(%{reduce_only: true}, notional), do: -notional
  defp signed_notional(%{is_buy: true}, notional), do: notional
  defp signed_notional(%{is_buy: false}, notional), do: notional

  defp initial_margin(_notional, leverage) when leverage <= 0, do: 0.0
  defp initial_margin(notional, leverage), do: notional / leverage

  defp policy(opts), do: Map.merge(@default_policy, opts |> value(:policy, %{}) |> opts_map())

  defp leverage_value(%{"value" => value}), do: numeric(value)
  defp leverage_value(%{value: value}), do: numeric(value)
  defp leverage_value(value), do: numeric(value)

  defp ratio(_numerator, denominator) when denominator in [0, 0.0], do: 0.0
  defp ratio(numerator, denominator), do: numerator / denominator

  defp maybe_add(alerts, true, message), do: [message | alerts]
  defp maybe_add(alerts, false, _message), do: alerts

  defp value(map, key, default \\ nil)
  defp value(map, key, default) when is_map(map), do: map_get(map, key, default)
  defp value(list, key, default) when is_list(list), do: Keyword.get(list, key, default)

  defp map_get(map, key, default) do
    string_key = to_string(key)

    cond do
      Map.has_key?(map, key) -> Map.fetch!(map, key)
      Map.has_key?(map, string_key) -> Map.fetch!(map, string_key)
      true -> default
    end
  end

  defp opts_map(opts) when is_map(opts), do: opts
  defp opts_map(opts) when is_list(opts), do: Map.new(opts)

  defp nullable_numeric(nil), do: nil
  defp nullable_numeric("nil"), do: nil
  defp nullable_numeric(value), do: numeric(value)

  defp numeric(nil), do: 0.0
  defp numeric(value) when is_integer(value), do: value * 1.0
  defp numeric(value) when is_float(value), do: value

  defp numeric(value) when is_binary(value) do
    case Float.parse(value) do
      {number, _rest} -> number
      :error -> 0.0
    end
  end
end
