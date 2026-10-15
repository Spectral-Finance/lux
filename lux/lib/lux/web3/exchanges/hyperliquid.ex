defmodule Lux.Web3.Exchanges.Hyperliquid do
  @moduledoc """
  Hyperliquid L1 perpetual trading, position management, leverage control, and risk
  monitoring engine for Lux agents.

  Provides comprehensive capabilities for Hyperliquid perpetual futures:
  - **Perpetual Market Metadata & L2 Orderbook Feed**: Queries perpetual universe specs
    (max leverage, tick/lot sizes, maintenance margin ratios, funding rates, mark/oracle
    prices) and live L2 bid/ask depth.
  - **Order Placement & Execution**: Supports `:limit` (GTC/IOC/ALO), `:market`,
    `:trigger` (stop-loss / take-profit), and `:twap` (time-weighted average price)
    orders with reduce-only enforcement and order cancellation.
  - **Leverage & Margin Mode Management**: Configures per-asset leverage (`1x` up to
    `max_leverage`) and switches between `:cross` and `:isolated` margin modes, plus
    isolated margin top-ups/withdrawals.
  - **Position Tracking, Funding Analytics & Liquidation Protection**: Computes live
    unrealized/realized PnL, ROE%, maintenance margin requirements, exact liquidation
    prices, funding rate payments, and automated deleveraging / stop-loss protection.
  """

  @table :lux_hyperliquid_state
  @basis_points 10_000

  @default_markets %{
    "BTC" => %{
      coin: "BTC",
      asset_index: 0,
      sz_decimals: 5,
      max_leverage: 50,
      maintenance_margin_bps: 100,
      maker_fee_bps: 1.0,
      taker_fee_bps: 3.5,
      mark_price: 68_000.0,
      oracle_price: 67_990.0,
      funding_rate_hourly: 0.0000125,
      open_interest_usd: 820_000_000.0
    },
    "ETH" => %{
      coin: "ETH",
      asset_index: 1,
      sz_decimals: 4,
      max_leverage: 50,
      maintenance_margin_bps: 100,
      maker_fee_bps: 1.0,
      taker_fee_bps: 3.5,
      mark_price: 3_000.0,
      oracle_price: 3_001.5,
      funding_rate_hourly: 0.0000100,
      open_interest_usd: 460_000_000.0
    },
    "SOL" => %{
      coin: "SOL",
      asset_index: 2,
      sz_decimals: 2,
      max_leverage: 20,
      maintenance_margin_bps: 250,
      maker_fee_bps: 1.0,
      taker_fee_bps: 3.5,
      mark_price: 165.0,
      oracle_price: 164.8,
      funding_rate_hourly: 0.0000180,
      open_interest_usd: 210_000_000.0
    },
    "HYPE" => %{
      coin: "HYPE",
      asset_index: 3,
      sz_decimals: 2,
      max_leverage: 10,
      maintenance_margin_bps: 500,
      maker_fee_bps: 1.0,
      taker_fee_bps: 3.5,
      mark_price: 25.0,
      oracle_price: 25.0,
      funding_rate_hourly: 0.0000220,
      open_interest_usd: 95_000_000.0
    }
  }

  @type coin :: String.t()

  @doc """
  Lists perpetual market metadata across the Hyperliquid universe.
  """
  @spec list_markets() :: {:ok, [map()]}
  def list_markets do
    ensure_table!()

    markets =
      all_markets_map()
      |> Map.values()
      |> Enum.sort_by(& &1.asset_index)

    {:ok, markets}
  end

  @doc """
  Retrieves metadata, mark/oracle prices, and funding rates for a specific perpetual asset.
  """
  @spec get_market(coin()) :: {:ok, map()} | {:error, :market_not_found}
  def get_market(coin) when is_binary(coin) do
    ensure_table!()

    case Map.get(all_markets_map(), String.upcase(coin)) do
      nil -> {:error, :market_not_found}
      market -> {:ok, market}
    end
  end

  @doc """
  Updates market price or funding rate parameters in the local engine (useful for testing
  mark price moves and liquidation scenarios).
  """
  @spec update_market_price(coin(), number(), keyword()) :: {:ok, map()} | {:error, atom()}
  def update_market_price(coin, mark_price, opts \\ [])
      when is_binary(coin) and is_number(mark_price) and mark_price > 0 do
    with {:ok, market} <- get_market(coin) do
      oracle_price = Keyword.get(opts, :oracle_price, mark_price * 1.0)
      funding_rate = Keyword.get(opts, :funding_rate_hourly, market.funding_rate_hourly)

      updated = %{
        market
        | mark_price: mark_price * 1.0,
          oracle_price: oracle_price * 1.0,
          funding_rate_hourly: funding_rate
      }

      custom = get_state(:custom_markets, %{})
      put_state(:custom_markets, Map.put(custom, updated.coin, updated))
      {:ok, updated}
    end
  end

  @doc """
  Returns a simulated L2 orderbook snapshot (bids, asks, mid price, spread in bps) for `coin`.
  """
  @spec get_l2_orderbook(coin(), keyword()) :: {:ok, map()} | {:error, atom()}
  def get_l2_orderbook(coin, opts \\ []) when is_binary(coin) do
    levels = Keyword.get(opts, :levels, 5)

    with {:ok, market} <- get_market(coin) do
      mid = market.mark_price

      bids =
        for lvl <- 1..levels do
          px = Float.round(mid * (1.0 - lvl * 0.0002), 4)
          sz = Float.round(10_000.0 / mid * lvl, 4)
          %{price: px, size: sz, orders: lvl + 1}
        end

      asks =
        for lvl <- 1..levels do
          px = Float.round(mid * (1.0 + lvl * 0.0002), 4)
          sz = Float.round(10_000.0 / mid * lvl, 4)
          %{price: px, size: sz, orders: lvl + 1}
        end

      best_bid = hd(bids).price
      best_ask = hd(asks).price
      spread_bps = Float.round((best_ask - best_bid) / mid * @basis_points, 2)

      {:ok,
       %{
         coin: market.coin,
         mid_price: mid,
         spread_bps: spread_bps,
         bids: bids,
         asks: asks
       }}
    end
  end

  @doc """
  Configures account collateral balance (`USDC`) for a trader address.
  """
  @spec deposit_collateral(String.t(), number()) :: {:ok, map()} | {:error, atom()}
  def deposit_collateral(wallet, amount_usdc)
      when is_binary(wallet) and is_number(amount_usdc) and amount_usdc > 0 do
    ensure_table!()
    acct = get_account(wallet)
    updated = %{acct | collateral_usdc: Float.round(acct.collateral_usdc + amount_usdc, 4)}
    put_account(wallet, updated)
    {:ok, updated}
  end

  def deposit_collateral(_wallet, _amount), do: {:error, :invalid_amount}

  @doc """
  Sets leverage (`1..max_leverage`) and margin mode (`:cross` or `:isolated`) for a coin.
  """
  @spec set_leverage(String.t(), coin(), pos_integer(), :cross | :isolated) ::
          {:ok, map()} | {:error, atom()}
  def set_leverage(wallet, coin, leverage, margin_mode \\ :cross)
      when is_binary(wallet) and is_binary(coin) and is_integer(leverage) do
    with {:ok, market} <- get_market(coin),
         :ok <- validate_leverage(leverage, market.max_leverage),
         :ok <- validate_margin_mode(margin_mode) do
      acct = get_account(wallet)
      setting = %{leverage: leverage, margin_mode: margin_mode}
      updated_settings = Map.put(acct.leverage_settings, market.coin, setting)
      put_account(wallet, %{acct | leverage_settings: updated_settings})

      {:ok,
       %{
         wallet: wallet,
         coin: market.coin,
         leverage: leverage,
         margin_mode: margin_mode,
         max_leverage: market.max_leverage
       }}
    end
  end

  @doc """
  Adjusts isolated margin collateral assigned to an open position on `coin`.
  """
  @spec update_isolated_margin(String.t(), coin(), number()) :: {:ok, map()} | {:error, atom()}
  def update_isolated_margin(wallet, coin, delta_usdc)
      when is_binary(wallet) and is_binary(coin) and is_number(delta_usdc) do
    symbol = String.upcase(coin)
    acct = get_account(wallet)

    case Map.get(acct.positions, symbol) do
      nil ->
        {:error, :position_not_found}

      pos ->
        new_margin = pos.isolated_margin + delta_usdc

        cond do
          delta_usdc > 0 and acct.collateral_usdc < delta_usdc ->
            {:error, :insufficient_collateral}

          new_margin <= 0 ->
            {:error, :invalid_margin_reduction}

          true ->
            updated_pos = %{pos | isolated_margin: Float.round(new_margin, 4)}
            updated_positions = Map.put(acct.positions, symbol, updated_pos)

            updated_acct = %{
              acct
              | collateral_usdc: Float.round(acct.collateral_usdc - delta_usdc, 4),
                positions: updated_positions
            }

            put_account(wallet, updated_acct)
            {:ok, enrich_position(updated_pos, symbol)}
        end
    end
  end

  @doc """
  Places a perpetual order on Hyperliquid.

  Supported `:order_type` values:
  - `:market` — Executes immediately against mark/book price and updates position.
  - `:limit` — Resting limit order (`tif`: `:gtc`, `:ioc`, or `:alo`); fills immediately if
    marketable (and not `:alo`), otherwise rests on the open order book.
  - `:trigger` — Stop-loss (`:sl`) or take-profit (`:tp`) conditional trigger order with
    `trigger_price` and `reduce_only: true`.
  - `:twap` — Time-weighted average price order split into `slices` over `duration_minutes`,
    executing the first slice immediately.
  """
  @spec place_order(String.t(), map()) :: {:ok, map()} | {:error, atom()}
  def place_order(wallet, params) when is_binary(wallet) and is_map(params) do
    coin = fetch_param(params, :coin, "BTC") |> to_string() |> String.upcase()
    side = normalize_side(fetch_param(params, :side, :buy))
    size = fetch_param(params, :size, 0.0) * 1.0
    order_type = normalize_order_type(fetch_param(params, :order_type, :market))
    limit_price = fetch_param(params, :price)
    trigger_price = fetch_param(params, :trigger_price)
    reduce_only = fetch_param(params, :reduce_only, false)
    tif = fetch_param(params, :tif, :gtc)

    with {:ok, market} <- get_market(coin),
         :ok <- validate_order_size(size),
         :ok <- validate_reduce_only(wallet, market.coin, side, size, reduce_only) do
      execute_or_queue_order(wallet, market, %{
        side: side,
        size: size,
        order_type: order_type,
        price: limit_price,
        trigger_price: trigger_price,
        reduce_only: reduce_only,
        tif: tif,
        slices: fetch_param(params, :slices, 4),
        duration_minutes: fetch_param(params, :duration_minutes, 60)
      })
    end
  end

  @doc """
  Cancels an open resting limit, trigger, or TWAP order by `order_id`.
  """
  @spec cancel_order(String.t(), String.t()) :: {:ok, map()} | {:error, atom()}
  def cancel_order(wallet, order_id) when is_binary(wallet) and is_binary(order_id) do
    acct = get_account(wallet)

    case Enum.split_with(acct.open_orders, &(&1.order_id == order_id)) do
      {[target], remaining} ->
        canceled = %{target | status: :canceled}
        put_account(wallet, %{acct | open_orders: remaining})
        {:ok, canceled}

      {[], _} ->
        {:error, :order_not_found}
    end
  end

  @doc """
  Lists all open resting orders for a trader wallet, optionally filtered by `:coin`.
  """
  @spec list_open_orders(String.t(), keyword()) :: {:ok, [map()]}
  def list_open_orders(wallet, opts \\ []) when is_binary(wallet) do
    coin_filter = Keyword.get(opts, :coin)
    acct = get_account(wallet)

    orders =
      case coin_filter do
        nil -> acct.open_orders
        coin -> Enum.filter(acct.open_orders, &(&1.coin == String.upcase(coin)))
      end

    {:ok, orders}
  end

  @doc """
  Returns comprehensive position and margin state for `wallet`, including unrealized PnL,
  ROE%, maintenance margin, exact liquidation prices, and funding accrued.
  """
  @spec get_user_state(String.t()) :: {:ok, map()}
  def get_user_state(wallet) when is_binary(wallet) do
    acct = get_account(wallet)

    enriched_positions =
      acct.positions
      |> Enum.map(fn {coin, pos} -> enrich_position(pos, coin) end)
      |> Enum.reject(&(&1.size == 0.0))

    total_unrealized_pnl =
      Enum.reduce(enriched_positions, 0.0, fn p, acc -> acc + p.unrealized_pnl end)

    total_notional =
      Enum.reduce(enriched_positions, 0.0, fn p, acc -> acc + p.notional_usd end)

    total_maintenance_margin =
      Enum.reduce(enriched_positions, 0.0, fn p, acc -> acc + p.maintenance_margin_usd end)

    total_initial_margin =
      Enum.reduce(enriched_positions, 0.0, fn p, acc -> acc + p.margin_used_usd end)

    account_equity =
      Float.round(acct.collateral_usdc + total_initial_margin + total_unrealized_pnl, 4)

    margin_ratio_pct =
      if account_equity > 0 do
        Float.round(total_maintenance_margin / account_equity * 100.0, 2)
      else
        100.0
      end

    {:ok,
     %{
       wallet: wallet,
       free_collateral_usdc: acct.collateral_usdc,
       account_equity_usd: account_equity,
       total_notional_usd: Float.round(total_notional, 4),
       total_unrealized_pnl_usd: Float.round(total_unrealized_pnl, 4),
       realized_pnl_usd: acct.realized_pnl_usd,
       maintenance_margin_usd: Float.round(total_maintenance_margin, 4),
       margin_ratio_pct: margin_ratio_pct,
       positions: enriched_positions,
       open_orders_count: length(acct.open_orders)
     }}
  end

  @doc """
  Evaluates portfolio risk, liquidation distance, and hourly funding exposure for `wallet`.
  When `:auto_protect` is `true`, automatically places protective stop-loss or partial
  deleveraging orders for positions exceeding risk thresholds.
  """
  @spec assess_risk_and_protect(String.t(), keyword()) :: {:ok, map()}
  def assess_risk_and_protect(wallet, opts \\ []) when is_binary(wallet) do
    auto_protect = Keyword.get(opts, :auto_protect, false)
    warning_distance_pct = Keyword.get(opts, :warning_distance_pct, 10.0)
    critical_distance_pct = Keyword.get(opts, :critical_distance_pct, 5.0)

    {:ok, state} = get_user_state(wallet)

    position_risks =
      Enum.map(state.positions, fn pos ->
        dist_pct = pos.liquidation_distance_pct

        risk_level =
          cond do
            dist_pct <= critical_distance_pct -> :critical
            dist_pct <= warning_distance_pct -> :warning
            true -> :healthy
          end

        protective_action =
          if auto_protect and risk_level == :critical do
            reduce_sz = Float.round(abs(pos.size) * 0.5, 4)
            close_side = if pos.side == :long, do: :sell, else: :buy

            {:ok, order} =
              place_order(wallet, %{
                coin: pos.coin,
                side: close_side,
                size: reduce_sz,
                order_type: :market,
                reduce_only: true
              })

            %{action: :auto_deleveraged_50_pct, order_id: order.order_id, size_closed: reduce_sz}
          else
            nil
          end

        %{
          coin: pos.coin,
          side: pos.side,
          size: pos.size,
          mark_price: pos.mark_price,
          liquidation_price: pos.liquidation_price,
          liquidation_distance_pct: dist_pct,
          hourly_funding_usd: pos.hourly_funding_usd,
          risk_level: risk_level,
          protective_action: protective_action
        }
      end)

    overall_status =
      cond do
        Enum.any?(position_risks, &(&1.risk_level == :critical)) -> :critical
        Enum.any?(position_risks, &(&1.risk_level == :warning)) -> :warning
        true -> :healthy
      end

    {:ok,
     %{
       wallet: wallet,
       overall_risk_status: overall_status,
       account_equity_usd: state.account_equity_usd,
       margin_ratio_pct: state.margin_ratio_pct,
       position_risks: position_risks
     }}
  end

  @doc """
  Resets all Hyperliquid markets, accounts, positions, and orders back to clean defaults.
  """
  @spec reset_state!() :: :ok
  def reset_state! do
    ensure_table!()
    :ets.delete_all_objects(@table)
    :ok
  end

  # Private implementation helpers

  defp execute_or_queue_order(wallet, market, spec) do
    order_id = generate_order_id({wallet, market.coin, spec})

    case spec.order_type do
      :market ->
        fill_order(wallet, market, order_id, spec.side, spec.size, market.mark_price, :market)

      :limit ->
        exec_price = (spec.price || market.mark_price) * 1.0

        marketable? =
          (spec.side == :buy and exec_price >= market.mark_price) or
            (spec.side == :sell and exec_price <= market.mark_price)

        if marketable? and spec.tif != :alo do
          fill_order(wallet, market, order_id, spec.side, spec.size, exec_price, :limit)
        else
          queue_resting_order(wallet, market, order_id, spec)
        end

      :trigger ->
        if is_nil(spec.trigger_price) do
          {:error, :missing_trigger_price}
        else
          queue_resting_order(wallet, market, order_id, spec)
        end

      :twap ->
        slices = max(spec.slices, 1)
        slice_size = Float.round(spec.size / slices, 5)

        with {:ok, first_fill} <-
               fill_order(
                 wallet,
                 market,
                 order_id <> "-s1",
                 spec.side,
                 slice_size,
                 market.mark_price,
                 :twap
               ) do
          {:ok,
           Map.merge(first_fill, %{
             order_id: order_id,
             order_type: :twap,
             total_size: spec.size,
             executed_slice_size: slice_size,
             remaining_size: Float.round(spec.size - slice_size, 5),
             slices: slices,
             duration_minutes: spec.duration_minutes
           })}
        end
    end
  end

  defp fill_order(wallet, market, order_id, side, size, fill_price, order_type) do
    acct = get_account(wallet)
    lev_cfg = Map.get(acct.leverage_settings, market.coin, %{leverage: 10, margin_mode: :cross})
    notional = size * fill_price
    fee_usd = Float.round(notional * (market.taker_fee_bps / @basis_points), 4)
    required_margin = Float.round(notional / lev_cfg.leverage, 4)

    signed_delta = if side == :buy, do: size, else: -size

    current_pos =
      Map.get(acct.positions, market.coin, %{
        coin: market.coin,
        size: 0.0,
        entry_price: 0.0,
        leverage: lev_cfg.leverage,
        margin_mode: lev_cfg.margin_mode,
        isolated_margin: 0.0
      })

    reducing? =
      current_pos.size != 0.0 and
        ((current_pos.size > 0 and signed_delta < 0) or
           (current_pos.size < 0 and signed_delta > 0))

    if not reducing? and acct.collateral_usdc < required_margin + fee_usd do
      {:error, :insufficient_collateral}
    else
      {new_pos, realized_delta, collateral_delta} =
        apply_position_fill(current_pos, signed_delta, fill_price, lev_cfg, required_margin)

      new_positions =
        if abs(new_pos.size) < 1.0e-9 do
          Map.delete(acct.positions, market.coin)
        else
          Map.put(acct.positions, market.coin, new_pos)
        end

      updated_acct = %{
        acct
        | collateral_usdc:
            Float.round(acct.collateral_usdc + collateral_delta + realized_delta - fee_usd, 4),
          realized_pnl_usd: Float.round(acct.realized_pnl_usd + realized_delta - fee_usd, 4),
          positions: new_positions
      }

      put_account(wallet, updated_acct)

      {:ok,
       %{
         order_id: order_id,
         wallet: wallet,
         coin: market.coin,
         side: side,
         order_type: order_type,
         status: :filled,
         size: size,
         fill_price: fill_price,
         notional_usd: Float.round(notional, 4),
         fee_usd: fee_usd,
         realized_pnl_usd: Float.round(realized_delta, 4)
       }}
    end
  end

  defp apply_position_fill(pos, signed_delta, fill_price, lev_cfg, required_margin) do
    old_sz = pos.size
    new_sz = Float.round(old_sz + signed_delta, 6)

    cond do
      old_sz == 0.0 ->
        new_pos = %{
          pos
          | size: new_sz,
            entry_price: fill_price,
            leverage: lev_cfg.leverage,
            margin_mode: lev_cfg.margin_mode,
            isolated_margin: required_margin
        }

        {new_pos, 0.0, -required_margin}

      (old_sz > 0 and signed_delta > 0) or (old_sz < 0 and signed_delta < 0) ->
        total_abs = abs(old_sz) + abs(signed_delta)

        avg_entry =
          Float.round(
            (abs(old_sz) * pos.entry_price + abs(signed_delta) * fill_price) / total_abs,
            4
          )

        new_pos = %{
          pos
          | size: new_sz,
            entry_price: avg_entry,
            isolated_margin: Float.round(pos.isolated_margin + required_margin, 4)
        }

        {new_pos, 0.0, -required_margin}

      true ->
        closed_sz = min(abs(old_sz), abs(signed_delta))
        direction = if old_sz > 0, do: 1.0, else: -1.0
        realized = closed_sz * (fill_price - pos.entry_price) * direction
        closed_fraction = closed_sz / abs(old_sz)
        released_margin = Float.round(pos.isolated_margin * closed_fraction, 4)

        remaining_margin = Float.round(max(0.0, pos.isolated_margin - released_margin), 4)
        new_pos = %{pos | size: new_sz, isolated_margin: remaining_margin}
        {new_pos, realized, released_margin}
    end
  end

  defp queue_resting_order(wallet, market, order_id, spec) do
    acct = get_account(wallet)

    order = %{
      order_id: order_id,
      wallet: wallet,
      coin: market.coin,
      side: spec.side,
      order_type: spec.order_type,
      status: :resting,
      size: spec.size,
      price: spec.price || market.mark_price,
      trigger_price: spec.trigger_price,
      reduce_only: spec.reduce_only,
      tif: spec.tif
    }

    put_account(wallet, %{acct | open_orders: [order | acct.open_orders]})
    {:ok, order}
  end

  defp enrich_position(pos, coin) do
    {:ok, market} = get_market(coin)
    abs_sz = abs(pos.size)
    side = if pos.size >= 0, do: :long, else: :short
    direction = if side == :long, do: 1.0, else: -1.0
    notional = abs_sz * market.mark_price
    unrealized_pnl = Float.round(abs_sz * (market.mark_price - pos.entry_price) * direction, 4)
    margin_used = max(pos.isolated_margin, Float.round(notional / max(pos.leverage, 1), 4))
    roe_pct = if margin_used > 0, do: Float.round(unrealized_pnl / margin_used * 100.0, 2), else: 0.0
    maint_margin = Float.round(notional * (market.maintenance_margin_bps / @basis_points), 4)

    mm_rate = market.maintenance_margin_bps / @basis_points
    lev_ratio = 1.0 / max(pos.leverage, 1)

    liq_price =
      case side do
        :long -> Float.round(max(0.0, pos.entry_price * (1.0 - lev_ratio + mm_rate)), 4)
        :short -> Float.round(pos.entry_price * (1.0 + lev_ratio - mm_rate), 4)
      end

    liq_dist_pct =
      Float.round(abs(market.mark_price - liq_price) / max(market.mark_price, 1.0e-9) * 100.0, 2)

    hourly_funding =
      Float.round(notional * market.funding_rate_hourly * if(side == :long, do: -1.0, else: 1.0), 4)

    %{
      coin: coin,
      side: side,
      size: pos.size,
      entry_price: pos.entry_price,
      mark_price: market.mark_price,
      leverage: pos.leverage,
      margin_mode: pos.margin_mode,
      margin_used_usd: margin_used,
      isolated_margin: pos.isolated_margin,
      notional_usd: Float.round(notional, 4),
      unrealized_pnl: unrealized_pnl,
      roe_pct: roe_pct,
      maintenance_margin_usd: maint_margin,
      liquidation_price: liq_price,
      liquidation_distance_pct: liq_dist_pct,
      hourly_funding_usd: hourly_funding
    }
  end

  defp validate_leverage(lev, max_lev) when lev >= 1 and lev <= max_lev, do: :ok
  defp validate_leverage(_lev, _max_lev), do: {:error, :exceeds_max_leverage}

  defp validate_margin_mode(mode) when mode in [:cross, :isolated], do: :ok
  defp validate_margin_mode(_), do: {:error, :invalid_margin_mode}

  defp validate_order_size(size) when size > 0, do: :ok
  defp validate_order_size(_), do: {:error, :invalid_size}

  defp validate_reduce_only(_wallet, _coin, _side, _size, false), do: :ok

  defp validate_reduce_only(wallet, coin, side, size, true) do
    acct = get_account(wallet)

    case Map.get(acct.positions, coin) do
      nil ->
        {:error, :reduce_only_rejected}

      pos ->
        closing_long? = pos.size > 0 and side == :sell and size <= pos.size
        closing_short? = pos.size < 0 and side == :buy and size <= abs(pos.size)
        if closing_long? or closing_short?, do: :ok, else: {:error, :reduce_only_rejected}
    end
  end

  defp normalize_side(s) when s in [:buy, "buy", :long, "long"], do: :buy
  defp normalize_side(s) when s in [:sell, "sell", :short, "short"], do: :sell
  defp normalize_side(_), do: :buy

  defp normalize_order_type(t) when t in [:market, "market"], do: :market
  defp normalize_order_type(t) when t in [:limit, "limit"], do: :limit
  defp normalize_order_type(t) when t in [:trigger, "trigger", :stop, "stop"], do: :trigger
  defp normalize_order_type(t) when t in [:twap, "twap"], do: :twap
  defp normalize_order_type(_), do: :market

  defp fetch_param(map, key, default \\ nil) when is_map(map) and is_atom(key) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  defp all_markets_map do
    Map.merge(@default_markets, get_state(:custom_markets, %{}))
  end

  defp get_account(wallet) do
    accounts = get_state(:accounts, %{})

    Map.get(accounts, wallet, %{
      wallet: wallet,
      collateral_usdc: 100_000.0,
      realized_pnl_usd: 0.0,
      leverage_settings: %{},
      positions: %{},
      open_orders: []
    })
  end

  defp put_account(wallet, acct) do
    accounts = get_state(:accounts, %{})
    put_state(:accounts, Map.put(accounts, wallet, acct))
  end

  defp generate_order_id(payload) do
    hash =
      :crypto.hash(:sha256, :erlang.term_to_binary({payload, System.unique_integer()}))
      |> Base.encode16(case: :lower)
      |> binary_part(0, 16)

    "hl-" <> hash
  end

  defp ensure_table! do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

      _tid ->
        :ok
    end
  end

  defp get_state(key, default) do
    ensure_table!()

    case :ets.lookup(@table, key) do
      [{^key, val}] -> val
      [] -> default
    end
  end

  defp put_state(key, val) do
    ensure_table!()
    :ets.insert(@table, {key, val})
    :ok
  end
end
