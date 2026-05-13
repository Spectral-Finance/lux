defmodule Lux.Integrations.Hyperliquid.Perpetuals do
  @moduledoc """
  Hyperliquid perpetual trading planning and risk helpers.

  This module does not submit live orders or handle private keys. It builds
  request plans, normalizes position snapshots, calculates PnL and liquidation
  buffers, and produces risk decisions that API/signing adapters can enforce.
  """

  @api_base "https://api.hyperliquid.xyz"

  @doc """
  Builds an info endpoint request plan.
  """
  @spec info_request(atom(), map()) :: {:ok, map()} | {:error, String.t()}
  def info_request(type, attrs \\ %{})

  def info_request(:meta, attrs) do
    {:ok, request(:post, "/info", %{type: "meta"}, attrs)}
  end

  def info_request(:clearinghouse_state, %{user: user} = attrs) do
    {:ok, request(:post, "/info", %{type: "clearinghouseState", user: user}, attrs)}
  end

  def info_request(:open_orders, %{user: user} = attrs) do
    {:ok, request(:post, "/info", %{type: "openOrders", user: user}, attrs)}
  end

  def info_request(:all_mids, attrs) do
    {:ok, request(:post, "/info", %{type: "allMids"}, attrs)}
  end

  def info_request(type, _attrs), do: {:error, "Unsupported Hyperliquid info request: #{type}"}

  @doc """
  Builds an order action payload for a signer/API adapter.
  """
  @spec order_plan(map()) :: {:ok, map()} | {:error, String.t()}
  def order_plan(attrs) when is_map(attrs) do
    coin = value(attrs, :coin)
    side = value(attrs, :side)
    size = number(attrs, :size)

    cond do
      not is_binary(coin) or coin == "" ->
        {:error, "Missing Hyperliquid market coin"}

      side not in [:buy, :sell, "buy", "sell"] ->
        {:error, "Unsupported Hyperliquid order side"}

      size <= 0 ->
        {:error, "Order size must be positive"}

      true ->
        {:ok,
         %{
           action: :order,
           payload: %{
             coin: coin,
             is_buy: side in [:buy, "buy"],
             sz: size,
             limit_px: number(attrs, :limit_px),
             order_type: value(attrs, :order_type) || %{limit: %{tif: "Gtc"}},
             reduce_only: value(attrs, :reduce_only) || false
           },
           idempotency_key: value(attrs, :idempotency_key)
         }}
    end
  end

  @doc """
  Normalizes a position snapshot.
  """
  @spec position_snapshot(map()) :: map()
  def position_snapshot(attrs) when is_map(attrs) do
    entry = number(attrs, :entry_px)
    mark = number(attrs, :mark_px)
    size = number(attrs, :size)
    side = if size < 0, do: :short, else: :long
    abs_size = abs(size)
    pnl = pnl(side, abs_size, entry, mark)
    margin = max(number(attrs, :margin_used), 0.0)

    %{
      coin: value(attrs, :coin),
      side: side,
      size: abs_size,
      entry_px: entry,
      mark_px: mark,
      liquidation_px: number(attrs, :liquidation_px),
      margin_used: margin,
      leverage: number(attrs, :leverage),
      unrealized_pnl: pnl,
      roe: ratio(pnl, max(margin, 1.0))
    }
  end

  @doc """
  Calculates liquidation distance and severity.
  """
  @spec liquidation_buffer(map()) :: map()
  def liquidation_buffer(position) when is_map(position) do
    snapshot = position_snapshot(position)
    distance = abs(snapshot.mark_px - snapshot.liquidation_px)
    distance_ratio = ratio(distance, max(snapshot.mark_px, 1.0))

    %{
      coin: snapshot.coin,
      distance: distance,
      distance_ratio: distance_ratio,
      severity: liquidation_severity(distance_ratio)
    }
  end

  @doc """
  Evaluates position and order risk against policy limits.
  """
  @spec risk_decision(map(), map()) :: map()
  def risk_decision(attrs, policy \\ %{}) do
    max_leverage = value(policy, :max_leverage) || 5
    min_liquidation_buffer = value(policy, :min_liquidation_buffer) || 0.08
    position = position_snapshot(attrs)
    buffer = liquidation_buffer(attrs)

    cond do
      position.leverage > max_leverage ->
        %{
          allowed?: false,
          reason: :leverage_limit_exceeded,
          position: position,
          liquidation_buffer: buffer
        }

      buffer.distance_ratio < min_liquidation_buffer ->
        %{
          allowed?: false,
          reason: :liquidation_buffer_too_low,
          position: position,
          liquidation_buffer: buffer
        }

      true ->
        %{allowed?: true, reason: :within_policy, position: position, liquidation_buffer: buffer}
    end
  end

  @doc """
  Summarizes account margin from position snapshots.
  """
  @spec margin_summary([map()]) :: map()
  def margin_summary(positions) when is_list(positions) do
    snapshots = Enum.map(positions, &position_snapshot/1)
    margin_used = snapshots |> Enum.map(& &1.margin_used) |> Enum.sum()
    pnl = snapshots |> Enum.map(& &1.unrealized_pnl) |> Enum.sum()

    %{
      position_count: length(snapshots),
      margin_used: margin_used,
      unrealized_pnl: pnl,
      average_roe: snapshots |> Enum.map(& &1.roe) |> average()
    }
  end

  @doc """
  Builds a safe execution decision for an order and current position.
  """
  @spec execution_decision(map(), map(), map()) :: map()
  def execution_decision(order_attrs, position_attrs, policy \\ %{}) do
    with {:ok, order} <- order_plan(order_attrs) do
      risk = risk_decision(position_attrs, policy)

      %{
        execute?: risk.allowed?,
        reason: risk.reason,
        order: order,
        risk: risk
      }
    else
      {:error, reason} -> %{execute?: false, reason: reason}
    end
  end

  defp request(method, endpoint, payload, attrs) do
    %{
      method: method,
      base_url: @api_base,
      endpoint: endpoint,
      url: @api_base <> endpoint,
      payload: payload,
      headers: value(attrs, :headers) || []
    }
  end

  defp pnl(:long, size, entry, mark), do: (mark - entry) * size
  defp pnl(:short, size, entry, mark), do: (entry - mark) * size

  defp liquidation_severity(ratio) when ratio < 0.03, do: :critical
  defp liquidation_severity(ratio) when ratio < 0.08, do: :warning
  defp liquidation_severity(_ratio), do: :healthy

  defp average([]), do: 0.0
  defp average(values), do: Enum.sum(values) / length(values)

  defp ratio(_numerator, 0), do: 0.0
  defp ratio(numerator, denominator), do: numerator / denominator

  defp number(map, key) do
    case value(map, key) do
      value when is_integer(value) -> value * 1.0
      value when is_float(value) -> value
      value when is_binary(value) ->
        case Float.parse(value) do
          {parsed, _rest} -> parsed
          :error -> 0.0
        end

      _other ->
        0.0
    end
  end

  defp value(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp value(_map, _key), do: nil
end
