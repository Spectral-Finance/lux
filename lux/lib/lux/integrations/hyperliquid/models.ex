defmodule Lux.Integrations.Hyperliquid.Models do
  @moduledoc """
  Elixir structs mirroring Hyperliquid API response structures.

  Provides type-safe data structures for orders, positions,
  account state, market data, and funding information.
  """

  alias Lux.Integrations.Hyperliquid.Models

  defmodule Order do
    @moduledoc "Represents a Hyperliquid order."
    defstruct [
      :order_id,
      :asset,
      :client_order_id,
      :is_buy,
      :size,
      :price,
      :limit_px,
      :stop_px,
      :reduce_only,
      :trigger_price,
      :trigger_type,
      :order_type,
      :time_in_force,
      :status,
      :filled_size,
      :avg_fill_price,
      :timestamp,
      :hash,
      :error
    ]

    @type t :: %__MODULE__{
      order_id: integer() | nil,
      asset: String.t() | nil,
      client_order_id: String.t() | nil,
      is_buy: boolean() | nil,
      size: String.t() | nil,
      price: String.t() | nil,
      limit_px: String.t() | nil,
      stop_px: String.t() | nil,
      reduce_only: boolean() | nil,
      trigger_price: String.t() | nil,
      trigger_type: String.t() | nil,
      order_type: map() | nil,
      time_in_force: String.t() | nil,
      status: String.t() | nil,
      filled_size: String.t() | nil,
      avg_fill_price: String.t() | nil,
      timestamp: integer() | nil,
      hash: String.t() | nil,
      error: String.t() | nil
    }
  end

  defmodule Position do
    @moduledoc "Represents a Hyperliquid position."
    defstruct [
      :asset,
      :size,
      :entry_price,
      :leverage,
      :liquidation_price,
      :margin_used,
      :position_value,
      :return_on_equity,
      :unrealized_pnl,
      :margin_mode,
      :max_leverage
    ]

    @type t :: %__MODULE__{
      asset: String.t() | nil,
      size: String.t() | nil,
      entry_price: String.t() | nil,
      leverage: String.t() | nil,
      liquidation_price: String.t() | nil,
      margin_used: String.t() | nil,
      position_value: String.t() | nil,
      return_on_equity: String.t() | nil,
      unrealized_pnl: String.t() | nil,
      margin_mode: String.t() | nil,
      max_leverage: String.t() | nil
    }
  end

  defmodule Account do
    @moduledoc "Represents a Hyperliquid account state."
    defstruct [
      :address,
      :account_value,
      :total_margin_used,
      :total_ntl_pos,
      :total_raw_usd,
      :maintenance_margin_ratio,
      :available_margin,
      :margin_ratio,
      :withdrawable,
      :positions,
      :open_orders
    ]

    @type t :: %__MODULE__{
      address: String.t() | nil,
      account_value: String.t() | nil,
      total_margin_used: String.t() | nil,
      total_ntl_pos: String.t() | nil,
      total_raw_usd: String.t() | nil,
      maintenance_margin_ratio: String.t() | nil,
      available_margin: String.t() | nil,
      margin_ratio: String.t() | nil,
      withdrawable: String.t() | nil,
      positions: [Models.Position.t()] | nil,
      open_orders: [Models.Order.t()] | nil
    }
  end

  defmodule MarketData do
    @moduledoc "Represents Hyperliquid market data for a token."
    defstruct [
      :asset,
      :funding,
      :open_interest,
      :prev_day_px,
      :day_ntl_vlm,
      :premium,
      :oracle_px,
      :mark_px,
      :mid_px,
      :impact_pxs,
      :day_base_vlm,
      :sz_decimals
    ]

    @type t :: %__MODULE__{
      asset: String.t() | nil,
      funding: String.t() | nil,
      open_interest: String.t() | nil,
      prev_day_px: String.t() | nil,
      day_ntl_vlm: String.t() | nil,
      premium: String.t() | nil,
      oracle_px: String.t() | nil,
      mark_px: String.t() | nil,
      mid_px: String.t() | nil,
      impact_pxs: [String.t()] | nil,
      day_base_vlm: String.t() | nil,
      sz_decimals: integer() | nil
    }
  end

  defmodule OrderBook do
    @moduledoc "Represents a Hyperliquid L2 order book."
    defstruct [
      :asset,
      :timestamp,
      :asks,
      :bids
    ]

    @type level :: %{price: String.t(), size: String.t()}

    @type t :: %__MODULE__{
      asset: String.t() | nil,
      timestamp: integer() | nil,
      asks: [level()] | nil,
      bids: [level()] | nil
    }
  end

  defmodule Trade do
    @moduledoc "Represents a Hyperliquid trade/match."
    defstruct [
      :asset,
      :side,
      :size,
      :price,
      :timestamp,
      :hash
    ]

    @type t :: %__MODULE__{
      asset: String.t() | nil,
      side: String.t() | nil,
      size: String.t() | nil,
      price: String.t() | nil,
      timestamp: integer() | nil,
      hash: String.t() | nil
    }
  end

  defmodule FundingRate do
    @moduledoc "Represents a Hyperliquid funding rate for an asset."
    defstruct [
      :asset,
      :funding_rate,
      :premium,
      :next_funding_time
    ]

    @type t :: %__MODULE__{
      asset: String.t() | nil,
      funding_rate: String.t() | nil,
      premium: String.t() | nil,
      next_funding_time: integer() | nil
    }
  end

  defmodule MarginChange do
    @moduledoc "Represents a margin modification request or result."
    defstruct [
      :asset,
      :amount,
      :is_deposit,
      :mode,
      :leverage,
      :status,
      :hash
    ]

    @type t :: %__MODULE__{
      asset: String.t() | nil,
      amount: String.t() | nil,
      is_deposit: boolean() | nil,
      mode: String.t() | nil,
      leverage: integer() | nil,
      status: String.t() | nil,
      hash: String.t() | nil
    }
  end

  @doc """
  Parses a position from the Hyperliquid API response into a Position struct.
  """
  @spec parse_position(map()) :: Position.t()
  def parse_position(%{"position" => pos} = raw) do
    %Position{
      asset: raw["coin"] || pos["coin"],
      size: pos["szi"],
      entry_price: pos["entryPx"],
      leverage: pos["leverage"] && pos["leverage"]["value"],
      liquidation_price: pos["liquidationPx"],
      margin_used: pos["marginUsed"],
      position_value: pos["positionValue"],
      return_on_equity: pos["returnOnEquity"],
      unrealized_pnl: pos["unrealizedPnl"],
      margin_mode: pos["marginMode"],
      max_leverage: pos["maxLeverage"]
    }
  end

  @doc """
  Parses an order from the Hyperliquid API response into an Order struct.
  """
  @spec parse_order(map()) :: Order.t()
  def parse_order(raw) do
    %Order{
      order_id: raw["oid"],
      asset: raw["coin"],
      is_buy: raw["side"] == "B",
      size: raw["origSz"] || raw["sz"],
      price: raw["limitPx"] || raw["limit_px"],
      limit_px: raw["limitPx"] || raw["limit_px"],
      reduce_only: raw["reduceOnly"],
      order_type: raw["orderType"] || raw["order_type"],
      status: raw["status"],
      filled_size: raw["totalSz"] || raw["filled_size"],
      avg_fill_price: raw["avgPx"] || raw["avg_px"],
      timestamp: raw["timestamp"],
      hash: raw["hash"],
      error: raw["error"]
    }
  end

  @doc """
  Parses account state from the Hyperliquid API response into an Account struct.
  """
  @spec parse_account(map()) :: Account.t()
  def parse_account(raw) do
    margin_summary = raw["crossMarginSummary"] || raw["marginSummary"] || %{}

    positions =
      (raw["assetPositions"] || [])
      |> Enum.map(&parse_position/1)

    %Account{
      address: raw["address"],
      account_value: margin_summary["accountValue"],
      total_margin_used: margin_summary["totalMarginUsed"],
      total_ntl_pos: margin_summary["totalNtlPos"],
      total_raw_usd: margin_summary["totalRawUsd"],
      maintenance_margin_ratio: raw["crossMaintenanceMarginRatio"],
      available_margin: margin_summary["availableMargin"],
      margin_ratio: raw["marginRatio"],
      withdrawable: raw["withdrawable"],
      positions: positions,
      open_orders: []
    }
  end

  @doc """
  Parses market data from the Hyperliquid API response into a MarketData struct.
  """
  @spec parse_market_data(String.t(), map()) :: MarketData.t()
  def parse_market_data(asset, raw) do
    %MarketData{
      asset: asset,
      funding: raw["funding"],
      open_interest: raw["openInterest"],
      prev_day_px: raw["prevDayPx"],
      day_ntl_vlm: raw["dayNtlVlm"],
      premium: raw["premium"],
      oracle_px: raw["oraclePx"],
      mark_px: raw["markPx"],
      mid_px: raw["midPx"],
      impact_pxs: raw["impactPxs"],
      day_base_vlm: raw["dayBaseVlm"],
      sz_decimals: raw["szDecimals"]
    }
  end
end
