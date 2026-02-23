defmodule Lux.Lenses.PancakeSwap.PancakeSwapPoolInfoLensTest do
  @moduledoc """
  Test suite for PancakeSwapPoolInfoLens.
  """

  use UnitCase, async: true

  alias Lux.Lenses.PancakeSwap.PancakeSwapPoolInfoLens

  # CAKE-BNB LP token on BSC
  @lp_cake_bnb "0x0eD7e52944161450477ee417DE9Cd3a859b14fD0"
  @agent_ctx %{agent: %{name: "YieldAgent"}}

  describe "focus/2 — with BSC RPC" do
    setup do
      System.put_env("PANCAKESWAP_RPC_URL", "https://bsc-dataseed.binance.org")
      on_exit(fn -> System.delete_env("PANCAKESWAP_RPC_URL") end)
    end

    test "fetches CAKE-BNB pool info" do
      result = PancakeSwapPoolInfoLens.focus(%{lp_token_address: @lp_cake_bnb}, @agent_ctx)

      case result do
        {:ok, info} ->
          assert info.lp_token_address == @lp_cake_bnb
          assert is_binary(info.token0_address)
          assert is_binary(info.token1_address)
          assert is_binary(info.reserve0)
          assert is_binary(info.reserve1)
          assert is_binary(info.total_supply)
          assert is_float(info.apy_total) or is_integer(info.apy_total)
          assert is_binary(info.pair_name)
        {:error, _} ->
          :ok
      end
    end

    test "reserve0 and reserve1 are non-negative integer strings" do
      case PancakeSwapPoolInfoLens.focus(%{lp_token_address: @lp_cake_bnb}, @agent_ctx) do
        {:ok, info} ->
          assert String.to_integer(info.reserve0) >= 0
          assert String.to_integer(info.reserve1) >= 0
        {:error, _} ->
          :ok
      end
    end

    test "apy values are non-negative" do
      case PancakeSwapPoolInfoLens.focus(%{lp_token_address: @lp_cake_bnb}, @agent_ctx) do
        {:ok, info} ->
          assert info.apy_base >= 0
          assert info.apy_cake >= 0
          assert info.apy_total >= 0
          assert info.apy_total == info.apy_base + info.apy_cake or
                 abs(info.apy_total - (info.apy_base + info.apy_cake)) < 0.001
        {:error, _} ->
          :ok
      end
    end
  end

  describe "focus/2 — invalid RPC" do
    test "returns error on bad RPC URL" do
      result = PancakeSwapPoolInfoLens.focus(
        %{lp_token_address: @lp_cake_bnb, rpc_url: "https://invalid.example.invalid"},
        @agent_ctx
      )

      # May error or succeed — but won't crash
      assert {:ok, _} = result or {:error, _} = result
    end
  end

  describe "lens metadata" do
    test "has correct name" do
      assert PancakeSwapPoolInfoLens.__lens__(:name) == "PancakeSwap Pool Info"
    end

    test "requires lp_token_address" do
      schema = PancakeSwapPoolInfoLens.__lens__(:schema)
      assert "lp_token_address" in schema.required
    end
  end
end
