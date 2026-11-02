defmodule Lux.Defi.UniswapV3.PoolManager do
  @moduledoc """
  Manages Uniswap V3 pool discovery, state tracking, CREATE2 deterministic address calculation,
  and optimal fee tier recommendation.
  """

  @factory_address "0x1F98431c8aD98523631AE4a59f267346ea31F984"
  @pool_init_code_hash "0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea0d3e41d21ab0ebd43"

  @fee_tiers %{
    100 => %{fee: 100, fee_pct: 0.01, tick_spacing: 1, name: "0.01% (Stable)"},
    500 => %{fee: 500, fee_pct: 0.05, tick_spacing: 10, name: "0.05% (Correlated/Majors)"},
    3000 => %{fee: 3000, fee_pct: 0.30, tick_spacing: 60, name: "0.30% (Standard)"},
    10000 => %{fee: 10000, fee_pct: 1.00, tick_spacing: 200, name: "1.00% (Exotic)"}
  }

  @type fee_tier :: 100 | 500 | 3000 | 10000
  @type pool_state :: %{
          address: String.t(),
          token0: String.t(),
          token1: String.t(),
          fee: fee_tier(),
          tick_spacing: pos_integer(),
          sqrt_price_x96: pos_integer(),
          tick: integer(),
          liquidity: non_neg_integer(),
          fee_growth_global0_x128: non_neg_integer(),
          fee_growth_global1_x128: non_neg_integer()
        }

  @doc """
  Returns metadata for all supported fee tiers.
  """
  @spec fee_tiers() :: map()
  def fee_tiers, do: @fee_tiers

  @doc """
  Returns the tick spacing for a given fee tier.
  """
  @spec tick_spacing_for_fee(fee_tier()) :: pos_integer()
  def tick_spacing_for_fee(fee) when is_integer(fee) do
    case Map.get(@fee_tiers, fee) do
      %{tick_spacing: ts} -> ts
      _ -> 60
    end
  end

  @doc """
  Orders two token addresses canonically (token0 < token1).
  """
  @spec sort_tokens(String.t(), String.t()) :: {:ok, {String.t(), String.t()}} | {:error, :identical_tokens}
  def sort_tokens(token_a, token_b) when is_binary(token_a) and is_binary(token_b) do
    clean_a = String.downcase(token_a)
    clean_b = String.downcase(token_b)

    cond do
      clean_a == clean_b -> {:error, :identical_tokens}
      clean_a < clean_b -> {:ok, {clean_a, clean_b}}
      true -> {:ok, {clean_b, clean_a}}
    end
  end

  @doc """
  Computes the deterministic CREATE2 address for a Uniswap V3 pool.
  """
  @spec compute_pool_address(String.t(), String.t(), fee_tier(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def compute_pool_address(token_a, token_b, fee, factory \\ @factory_address) do
    with {:ok, {token0, token1}} <- sort_tokens(token_a, token_b) do
      token0_bin = address_to_bytes(token0)
      token1_bin = address_to_bytes(token1)
      factory_bin = address_to_bytes(factory)

      # ABI encode (token0, token1, fee) for salt
      salt = :crypto.hash(:sha3_256, <<0::96, token0_bin::binary-size(20), 0::96, token1_bin::binary-size(20), fee::256>>)
      init_code_hash = Base.decode16!(@pool_init_code_hash |> String.trim_leading("0x"), case: :lower)

      payload = <<0xFF, factory_bin::binary-size(20), salt::binary-size(32), init_code_hash::binary-size(32)>>
      hash = :crypto.hash(:sha3_256, payload)
      <<_::binary-size(12), pool_addr::binary-size(20)>> = hash

      {:ok, "0x" <> Base.encode16(pool_addr, case: :lower)}
    end
  end

  @doc """
  Recommends the optimal fee tier based on token pair volatility characteristics:
  - `:stable`: 100 (USDC/USDT, DAI/USDC)
  - `:correlated`: 500 (WETH/USDC, WBTC/USDC, wstETH/ETH)
  - `:standard`: 3000 (Most normal ERC-20 pairs)
  - `:exotic`: 10000 (Low liquidity, meme tokens, high volatility)
  """
  @spec recommend_fee_tier(atom() | String.t()) :: fee_tier()
  def recommend_fee_tier(category) do
    case to_string(category) |> String.downcase() do
      "stable" -> 100
      "correlated" -> 500
      "majors" -> 500
      "exotic" -> 10000
      _ -> 3000
    end
  end

  @doc """
  Builds a structured pool state map.
  """
  @spec build_pool_state(String.t(), String.t(), fee_tier(), pos_integer(), integer(), non_neg_integer()) ::
          pool_state()
  def build_pool_state(token0, token1, fee, sqrt_price_x96, tick, liquidity) do
    {:ok, pool_addr} = compute_pool_address(token0, token1, fee)
    spacing = tick_spacing_for_fee(fee)

    %{
      address: pool_addr,
      token0: String.downcase(token0),
      token1: String.downcase(token1),
      fee: fee,
      tick_spacing: spacing,
      sqrt_price_x96: sqrt_price_x96,
      tick: tick,
      liquidity: liquidity,
      fee_growth_global0_x128: 0,
      fee_growth_global1_x128: 0
    }
  end

  defp address_to_bytes(address) do
    hex = address |> String.trim_leading("0x") |> String.downcase()
    Base.decode16!(hex, case: :lower)
  end
end
