defmodule Lux.Integrations.Binance.Models do
  @moduledoc """
  Elixir structs mirroring Binance API response structures.

  Provides type-safe data structures for orders, positions,
  account balances, market data, and trade information.
  """

  alias Lux.Integrations.Binance.Models

  defmodule Order do
    @moduledoc "Represents a Binance order."
    defstruct [
      :order_id,
      :client_order_id,
      :symbol,
      :side,
      :type,
      :time_in_force,
      :quantity,
      :price,
      :stop_price,
      :status,
      :filled_quantity,
      :cumulative_quote_qty,
      :avg_fill_price,
      :timestamp,
      :update_time,
      :reduce_only,
      :position_side,
      :working_type
    ]

    @type t :: %__MODULE__{
      order_id: integer() | nil,
      client_order_id: String.t() | nil,
      symbol: String.t() | nil,
      side: String.t() | nil,
      type: String.t() | nil,
      time_in_force: String.t() | nil,
      quantity: String.t() | nil,
      price: String.t() | nil,
      stop_price: String.t() | nil,
      status: String.t() | nil,
      filled_quantity: String.t() | nil,
      cumulative_quote_qty: String.t() | nil,
      avg_fill_price: String.t() | nil,
      timestamp: integer() | nil,
      update_time: integer() | nil,
      reduce_only: boolean() | nil,
      position_side: String.t() | nil,
      working_type: String.t() | nil
    }
  end

  defmodule Position do
    @moduledoc "Represents a Binance futures position."
    defstruct [
      :symbol,
      :position_side,
      :entry_price,
      :mark_price,
      :quantity,
      :leverage,
      :margin_type,
      :isolated_margin,
      :liquidation_price,
      :unrealized_pnl,
      :position_value,
      :notional,
      :initial_margin,
      :maintenance_margin
    ]

    @type t :: %__MODULE__{
      symbol: String.t() | nil,
      position_side: String.t() | nil,
      entry_price: String.t() | nil,
      mark_price: String.t() | nil,
      quantity: String.t() | nil,
      leverage: String.t() | nil,
      margin_type: String.t() | nil,
      isolated_margin: String.t() | nil,
      liquidation_price: String.t() | nil,
      unrealized_pnl: String.t() | nil,
      position_value: String.t() | nil,
      notional: String.t() | nil,
      initial_margin: String.t() | nil,
      maintenance_margin: String.t() | nil
    }
  end

  defmodule Balance do
    @moduledoc "Represents a Binance wallet balance for an asset."
    defstruct [
      :asset,
      :free,
      :locked,
      :total,
      :usd_value
    ]

    @type t :: %__MODULE__{
      asset: String.t() | nil,
      free: String.t() | nil,
      locked: String.t() | nil,
      total: String.t() | nil,
      usd_value: String.t() | nil
    }
  end

  defmodule Account do
    @moduledoc "Represents a Binance account state."
    defstruct [
      :total_wallet_balance,
      :total_unrealized_pnl,
      :total_margin_balance,
      :available_balance,
      :positions,
      :balances,
      :can_trade,
      :can_deposit,
      :can_withdraw,
      :account_type
    ]

    @type t :: %__MODULE__{
      total_wallet_balance: String.t() | nil,
      total_unrealized_pnl: String.t() | nil,
      total_margin_balance: String.t() | nil,
      available_balance: String.t() | nil,
      positions: [Models.Position.t()] | nil,
      balances: [Models.Balance.t()] | nil,
      can_trade: boolean() | nil,
      can_deposit: boolean() | nil,
      can_withdraw: boolean() | nil,
      account_type: String.t() | nil
    }
  end

  defmodule Market do
    @moduledoc "Represents Binance market/exchange info for a symbol."
    defstruct [
      :symbol,
      :status,
      :base_asset,
      :quote_asset,
      :price_tick_size,
      :quantity_tick_size,
      :min_notional,
      :is_spot_trading_allowed,
      :is_margin_trading_allowed,
      :filters
    ]

    @type t :: %__MODULE__{
      symbol: String.t() | nil,
      status: String.t() | nil,
      base_asset: String.t() | nil,
      quote_asset: String.t() | nil,
      price_tick_size: String.t() | nil,
      quantity_tick_size: String.t() | nil,
      min_notional: String.t() | nil,
      is_spot_trading_allowed: boolean() | nil,
      is_margin_trading_allowed: boolean() | nil,
      filters: [map()] | nil
    }
  end

  defmodule OrderBook do
    @moduledoc "Represents a Binance order book snapshot."
    defstruct [
      :symbol,
      :last_update_id,
      :bids,
      :asks,
      :timestamp
    ]

    @type level :: %{price: String.t(), quantity: String.t()}

    @type t :: %__MODULE__{
      symbol: String.t() | nil,
      last_update_id: integer() | nil,
      bids: [level()] | nil,
      asks: [level()] | nil,
      timestamp: integer() | nil
    }
  end

  defmodule Trade do
    @moduledoc "Represents a Binance trade/match."
    defstruct [
      :id,
      :symbol,
      :price,
      :quantity,
      :quote_quantity,
      :time,
      :is_buyer_maker
    ]

    @type t :: %__MODULE__{
      id: integer() | nil,
      symbol: String.t() | nil,
      price: String.t() | nil,
      quantity: String.t() | nil,
      quote_quantity: String.t() | nil,
      time: integer() | nil,
      is_buyer_maker: boolean() | nil
    }
  end

  defmodule Ticker do
    @moduledoc "Represents a Binance 24hr ticker."
    defstruct [
      :symbol,
      :price_change,
      :price_change_pct,
      :weighted_avg_price,
      :last_price,
      :last_quantity,
      :open_price,
      :high_price,
      :low_price,
      :volume,
      :quote_volume,
      :open_time,
      :close_time,
      :count
    ]

    @type t :: %__MODULE__{
      symbol: String.t() | nil,
      price_change: String.t() | nil,
      price_change_pct: String.t() | nil,
      weighted_avg_price: String.t() | nil,
      last_price: String.t() | nil,
      last_quantity: String.t() | nil,
      open_price: String.t() | nil,
      high_price: String.t() | nil,
      low_price: String.t() | nil,
      volume: String.t() | nil,
      quote_volume: String.t() | nil,
      open_time: integer() | nil,
      close_time: integer() | nil,
      count: integer() | nil
    }
  end

  defmodule Kline do
    @moduledoc "Represents a Binance candlestick/kline."
    defstruct [
      :open_time,
      :open,
      :high,
      :low,
      :close,
      :volume,
      :close_time,
      :quote_volume,
      :trades_count,
      :taker_buy_volume,
      :taker_buy_quote_volume
    ]

    @type t :: %__MODULE__{
      open_time: integer() | nil,
      open: String.t() | nil,
      high: String.t() | nil,
      low: String.t() | nil,
      close: String.t() | nil,
      volume: String.t() | nil,
      close_time: integer() | nil,
      quote_volume: String.t() | nil,
      trades_count: integer() | nil,
      taker_buy_volume: String.t() | nil,
      taker_buy_quote_volume: String.t() | nil
    }
  end

  @doc """
  Parses a Binance order response into an Order struct.
  """
  @spec parse_order(map()) :: Order.t()
  def parse_order(raw) do
    %Order{
      order_id: raw["i"] || raw["orderId"] || raw["order_id"],
      client_order_id: raw["c"] || raw["clientOrderId"] || raw["client_order_id"],
      symbol: raw["s"] || raw["symbol"],
      side: raw["S"] || raw["side"],
      type: raw["o"] || raw["type"],
      time_in_force: raw["f"] || raw["timeInForce"] || raw["time_in_force"],
      quantity: raw["q"] || raw["origQty"] || raw["orig_qty"] || raw["quantity"],
      price: raw["p"] || raw["price"],
      stop_price: raw["P"] || raw["stopPrice"] || raw["stop_price"],
      status: raw["X"] || raw["status"],
      filled_quantity: raw["z"] || raw["executedQty"] || raw["executed_qty"] || raw["filled_quantity"],
      cumulative_quote_qty: raw["Z"] || raw["cummulativeQuoteQty"] || raw["cummulative_quote_qty"],
      avg_fill_price: raw["avgPrice"] || raw["avg_price"],
      timestamp: raw["T"] || raw["time"] || raw["timestamp"],
      update_time: raw["updateTime"] || raw["update_time"],
      reduce_only: raw["reduceOnly"] || raw["reduce_only"],
      position_side: raw["positionSide"] || raw["position_side"],
      working_type: raw["workingType"] || raw["working_type"]
    }
  end

  @doc """
  Parses a Binance position response into a Position struct.
  """
  @spec parse_position(map()) :: Position.t()
  def parse_position(raw) do
    %Position{
      symbol: raw["symbol"],
      position_side: raw["positionSide"] || "BOTH",
      entry_price: raw["entryPrice"],
      mark_price: raw["markPrice"],
      quantity: raw["positionAmt"] || raw["quantity"],
      leverage: raw["leverage"],
      margin_type: raw["marginType"],
      isolated_margin: raw["isolatedMargin"] || raw["isolatedWallet"],
      liquidation_price: raw["liquidationPrice"],
      unrealized_pnl: raw["unRealizedProfit"] || raw["unrealized_pnl"],
      position_value: raw["positionInitialMargin"] || raw["position_value"],
      notional: raw["notional"],
      initial_margin: raw["initialMargin"],
      maintenance_margin: raw["maintMargin"]
    }
  end

  @doc """
  Parses a Binance balance entry into a Balance struct.
  """
  @spec parse_balance(map()) :: Balance.t()
  def parse_balance(raw) do
    %Balance{
      asset: raw["asset"],
      free: raw["free"],
      locked: raw["locked"],
      total: raw["total"] || raw["balance"],
      usd_value: raw["usdValue"] || raw["usd_value"]
    }
  end

  @doc """
  Parses a Binance account response into an Account struct.
  """
  @spec parse_account(map()) :: Account.t()
  def parse_account(raw) do
    positions =
      (raw["positions"] || [])
      |> Enum.map(&parse_position/1)

    balances =
      (raw["balances"] || raw["assets"] || [])
      |> Enum.map(&parse_balance/1)
      |> Enum.filter(fn b -> parse_float(b.total) > 0.0 end)

    %Account{
      total_wallet_balance: raw["totalWalletBalance"] || raw["total_wallet_balance"],
      total_unrealized_pnl: raw["totalUnrealizedProfit"] || raw["total_unrealized_pnl"],
      total_margin_balance: raw["totalMarginBalance"] || raw["total_margin_balance"],
      available_balance: raw["availableBalance"] || raw["available_balance"],
      positions: positions,
      balances: balances,
      can_trade: raw["canTrade"] || raw["can_trade"],
      can_deposit: raw["canDeposit"] || raw["can_deposit"],
      can_withdraw: raw["canWithdraw"] || raw["can_withdraw"],
      account_type: raw["accountType"] || raw["account_type"] || "SPOT"
    }
  end

  @doc """
  Parses Binance exchange info for a symbol into a Market struct.
  """
  @spec parse_market(String.t(), map()) :: Market.t()
  def parse_market(symbol, raw) do
    filters = raw["filters"] || []

    price_filter = Enum.find(filters, &(&1["filterType"] == "PRICE_FILTER"))
    lot_filter = Enum.find(filters, &(&1["filterType"] == "LOT_SIZE"))
    min_notional = Enum.find(filters, &(&1["filterType"] == "MIN_NOTIONAL")) ||
                   Enum.find(filters, &(&1["filterType"] == "NOTIONAL"))

    %Market{
      symbol: symbol,
      status: raw["status"],
      base_asset: raw["baseAsset"],
      quote_asset: raw["quoteAsset"],
      price_tick_size: (price_filter && price_filter["tickSize"]) || nil,
      quantity_tick_size: (lot_filter && lot_filter["stepSize"]) || nil,
      min_notional: (min_notional && min_notional["minNotional"]) || nil,
      is_spot_trading_allowed: raw["isSpotTradingAllowed"],
      is_margin_trading_allowed: raw["isMarginTradingAllowed"],
      filters: filters
    }
  end

  @doc """
  Parses a Binance order book response into an OrderBook struct.
  """
  @spec parse_order_book(String.t(), map()) :: OrderBook.t()
  def parse_order_book(symbol, raw) do
    %OrderBook{
      symbol: symbol,
      last_update_id: raw["lastUpdateId"],
      bids: Enum.map(raw["bids"] || [], fn [price, qty] -> %{price: price, quantity: qty} end),
      asks: Enum.map(raw["asks"] || [], fn [price, qty] -> %{price: price, quantity: qty} end),
      timestamp: raw["timestamp"] || System.system_time(:millisecond)
    }
  end

  @doc """
  Parses a Binance trade response into a Trade struct.
  """
  @spec parse_trade(map()) :: Trade.t()
  def parse_trade(raw) do
    %Trade{
      id: raw["id"] || raw["tradeId"],
      symbol: raw["symbol"],
      price: raw["price"],
      quantity: raw["qty"] || raw["quantity"],
      quote_quantity: raw["quoteQty"] || raw["quote_quantity"],
      time: raw["time"],
      is_buyer_maker: raw["isBuyerMaker"]
    }
  end

  @doc """
  Parses a Binance ticker into a Ticker struct.
  """
  @spec parse_ticker(map()) :: Ticker.t()
  def parse_ticker(raw) do
    %Ticker{
      symbol: raw["symbol"],
      price_change: raw["priceChange"],
      price_change_pct: raw["priceChangePercent"],
      weighted_avg_price: raw["weightedAvgPrice"],
      last_price: raw["lastPrice"],
      last_quantity: raw["lastQty"],
      open_price: raw["openPrice"],
      high_price: raw["highPrice"],
      low_price: raw["lowPrice"],
      volume: raw["volume"],
      quote_volume: raw["quoteVolume"],
      open_time: raw["openTime"],
      close_time: raw["closeTime"],
      count: raw["count"]
    }
  end

  @doc """
  Parses a Binance kline array into a Kline struct.
  """
  @spec parse_kline(list()) :: Kline.t()
  def parse_kline([
    open_time, open, high, low, close, volume,
    close_time, quote_volume, trades_count,
    taker_buy_volume, taker_buy_quote_volume, _
  ]) do
    %Kline{
      open_time: open_time,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
      close_time: close_time,
      quote_volume: quote_volume,
      trades_count: trades_count,
      taker_buy_volume: taker_buy_volume,
      taker_buy_quote_volume: taker_buy_quote_volume
    }
  end

  defp parse_float(nil), do: 0.0
  defp parse_float(str) when is_binary(str) do
    case Float.parse(str) do
      {val, _} -> val
      :error -> 0.0
    end
  end
  defp parse_float(num) when is_number(num), do: num
end
