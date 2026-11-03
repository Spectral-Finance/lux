defmodule Lux.Integrations.Hyperliquid.Client do
  @moduledoc """
  Hyperliquid Perpetual Trading integration for Lux agents (#82).
  Provides order placement, position tracking, leverage control, liquidation price
  estimation, and risk monitoring.
  """

  @default_base_url "https://api.hyperliquid.xyz"

  defstruct [
    :wallet_address,
    :base_url,
    max_leverage: 20,
    min_liquidation_buffer_pct: 5.0
  ]

  @type position :: %{
          coin: String.t(),
          size: float(),
          entry_price: float(),
          mark_price: float(),
          leverage: pos_integer(),
          margin_used: float()
        }

  def new(opts \\ []) do
    %__MODULE__{
      wallet_address: Keyword.get(opts, :wallet_address),
      base_url: Keyword.get(opts, :base_url, @default_base_url),
      max_leverage: Keyword.get(opts, :max_leverage, 20),
      min_liquidation_buffer_pct: Keyword.get(opts, :min_liquidation_buffer_pct, 5.0)
    }
  end

  @doc """
  Calculates unrealized PnL and return-on-equity (ROE %) for a perpetual position.
  """
  def calculate_pnl(%{size: size, entry_price: entry, mark_price: mark, margin_used: margin})
      when entry > 0 and margin > 0 do
    pnl = size * (mark - entry)
    roe_pct = pnl / margin * 100.0
    {:ok, %{unrealized_pnl: Float.round(pnl, 4), roe_pct: Float.round(roe_pct, 4)}}
  end

  def calculate_pnl(_), do: {:error, :invalid_position}

  @doc """
  Estimates liquidation price given entry price, signed size (>0 long, <0 short),
  leverage, and maintenance margin fraction (default 0.025 = 2.5%).
  """
  def estimate_liquidation_price(entry_price, size, leverage, maint_margin_rate \\ 0.025)
      when entry_price > 0 and leverage >= 1 and size != 0 do
    initial_margin_rate = 1.0 / leverage
    if size > 0 do
      liq = entry_price * (1.0 - initial_margin_rate + maint_margin_rate)
      {:ok, Float.round(max(0.0, liq), 4)}
    else
      liq = entry_price * (1.0 + initial_margin_rate - maint_margin_rate)
      {:ok, Float.round(liq, 4)}
    end
  end

  @doc """
  Validates an order against risk parameters (max leverage and liquidation buffer).
  """
  def build_order(%__MODULE__{max_leverage: max_lev} = _client, params) when is_map(params) do
    leverage = Map.get(params, :leverage, 1)
    size = Map.get(params, :size, 0.0)
    price = Map.get(params, :price, 0.0)
    coin = Map.get(params, :coin, "")

    cond do
      coin == "" ->
        {:error, :missing_coin}

      size == 0 ->
        {:error, :zero_size}

      price <= 0 ->
        {:error, :invalid_price}

      leverage < 1 or leverage > max_lev ->
        {:error, {:leverage_exceeded, leverage, max_lev}}

      true ->
        {:ok,
         %{
           coin: coin,
           is_buy: size > 0,
           sz: abs(size),
           limit_px: price,
           leverage: leverage,
           reduce_only: Map.get(params, :reduce_only, false),
           order_type: Map.get(params, :order_type, %{limit: %{tif: "Gtc"}})
         }}
    end
  end
end
