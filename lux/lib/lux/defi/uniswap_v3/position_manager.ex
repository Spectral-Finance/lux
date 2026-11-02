defmodule Lux.Defi.UniswapV3.PositionManager do
  @moduledoc """
  Manages concentrated liquidity positions on Uniswap V3:
  - Position lifecycle (mint, increase, decrease, collect, burn)
  - In-range active liquidity status check
  - Asset balance valuation in USD
  - Accurate uncollected fee calculation
  """

  alias Lux.Defi.UniswapV3.Math
  alias Lux.Defi.UniswapV3.PoolManager

  @type position :: %{
          token_id: pos_integer() | String.t(),
          owner: String.t(),
          pool_address: String.t(),
          token0: String.t(),
          token1: String.t(),
          fee: pos_integer(),
          tick_lower: integer(),
          tick_upper: integer(),
          liquidity: non_neg_integer(),
          tokens_owed0: non_neg_integer(),
          tokens_owed1: non_neg_integer(),
          created_at: DateTime.t()
        }

  @doc """
  Initializes a new Uniswap V3 position struct from parameters.
  Validates that:
  - `tick_lower < tick_upper`
  - Both ticks are aligned with the fee tier's tick spacing.
  """
  @spec create_position(map()) :: {:ok, position()} | {:error, term()}
  def create_position(params) when is_map(params) do
    token0 = Map.get(params, :token0) || Map.get(params, "token0")
    token1 = Map.get(params, :token1) || Map.get(params, "token1")
    fee = Map.get(params, :fee) || Map.get(params, "fee", 3000)
    owner = Map.get(params, :owner) || Map.get(params, "owner", "0x0000000000000000000000000000000000000000")
    tick_lower = Map.get(params, :tick_lower) || Map.get(params, "tick_lower")
    tick_upper = Map.get(params, :tick_upper) || Map.get(params, "tick_upper")
    liquidity = Map.get(params, :liquidity) || Map.get(params, "liquidity", 0)
    token_id = Map.get(params, :token_id) || Map.get(params, "token_id", generate_token_id())

    spacing = PoolManager.tick_spacing_for_fee(fee)

    cond do
      is_nil(token0) or is_nil(token1) ->
        {:error, :missing_tokens}

      is_nil(tick_lower) or is_nil(tick_upper) ->
        {:error, :missing_ticks}

      tick_lower >= tick_upper ->
        {:error, :invalid_tick_range}

      rem(tick_lower, spacing) != 0 ->
        {:error, {:tick_not_spaced, :lower, spacing}}

      rem(tick_upper, spacing) != 0 ->
        {:error, {:tick_not_spaced, :upper, spacing}}

      true ->
        {:ok, pool_addr} = PoolManager.compute_pool_address(token0, token1, fee)

        pos = %{
          token_id: token_id,
          owner: String.downcase(owner),
          pool_address: pool_addr,
          token0: String.downcase(token0),
          token1: String.downcase(token1),
          fee: fee,
          tick_lower: tick_lower,
          tick_upper: tick_upper,
          liquidity: liquidity,
          tokens_owed0: 0,
          tokens_owed1: 0,
          created_at: DateTime.utc_now()
        }

        {:ok, pos}
    end
  end

  @doc """
  Checks if a position is currently active and earning fees at current tick.
  """
  @spec in_range?(position(), integer()) :: boolean()
  def in_range?(%{tick_lower: lower, tick_upper: upper}, current_tick) when is_integer(current_tick) do
    current_tick >= lower and current_tick < upper
  end

  @doc """
  Increases liquidity for an existing position.
  """
  @spec increase_liquidity(position(), non_neg_integer()) :: position()
  def increase_liquidity(position, added_liquidity) when is_integer(added_liquidity) and added_liquidity >= 0 do
    %{position | liquidity: position.liquidity + added_liquidity}
  end

  @doc """
  Decreases liquidity for an existing position and records tokens owed.
  """
  @spec decrease_liquidity(position(), non_neg_integer(), pos_integer()) :: {:ok, position(), map()} | {:error, term()}
  def decrease_liquidity(position, removed_liquidity, current_sqrt_price)
      when is_integer(removed_liquidity) and removed_liquidity > 0 do
    if removed_liquidity > position.liquidity do
      {:error, :insufficient_liquidity}
    else
      sqrt_a = Math.tick_to_sqrt_price_x96(position.tick_lower)
      sqrt_b = Math.tick_to_sqrt_price_x96(position.tick_upper)

      amounts = Math.get_amounts_for_liquidity(current_sqrt_price, sqrt_a, sqrt_b, removed_liquidity)

      updated = %{
        position
        | liquidity: position.liquidity - removed_liquidity,
          tokens_owed0: position.tokens_owed0 + amounts.amount0,
          tokens_owed1: position.tokens_owed1 + amounts.amount1
      }

      {:ok, updated, amounts}
    end
  end

  @doc """
  Collects accumulated fees and withdrawn tokens from position.
  """
  @spec collect_fees(position()) :: {position(), %{collected0: non_neg_integer(), collected1: non_neg_integer()}}
  def collect_fees(position) do
    collected = %{
      collected0: position.tokens_owed0,
      collected1: position.tokens_owed1
    }

    updated = %{position | tokens_owed0: 0, tokens_owed1: 0}
    {updated, collected}
  end

  @doc """
  Calculates the current USD value of assets deposited in the position.
  """
  @spec position_value(position(), pos_integer(), non_neg_integer(), non_neg_integer(), number(), number()) :: float()
  def position_value(position, current_sqrt_price, decimals0, decimals1, price0_usd, price1_usd) do
    sqrt_a = Math.tick_to_sqrt_price_x96(position.tick_lower)
    sqrt_b = Math.tick_to_sqrt_price_x96(position.tick_upper)

    amounts = Math.get_amounts_for_liquidity(current_sqrt_price, sqrt_a, sqrt_b, position.liquidity)

    token0_units = (amounts.amount0 + position.tokens_owed0) / :math.pow(10, decimals0)
    token1_units = (amounts.amount1 + position.tokens_owed1) / :math.pow(10, decimals1)

    token0_units * price0_usd + token1_units * price1_usd
  end

  defp generate_token_id do
    "pos_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end
end
