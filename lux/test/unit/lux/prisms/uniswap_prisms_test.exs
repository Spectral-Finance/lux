defmodule Lux.Prisms.UniswapPrismsTest do
  use UnitCase, async: true

  alias Lux.Prisms.Uniswap.ExecuteSwap
  alias Lux.Prisms.Uniswap.AddLiquidity
  alias Lux.Prisms.Uniswap.RemoveLiquidity
  alias Lux.Prisms.Uniswap.CollectFees

  @test_token_a "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
  @test_token_b "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
  @recipient "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"

  describe "ExecuteSwap prism" do
    test "successfully encodes exact_input swap" do
      {:ok, result} =
        ExecuteSwap.run(%{
          token_in: @test_token_a,
          token_out: @test_token_b,
          fee: 3000,
          recipient: @recipient,
          amount_in: 1000000,
          amount_out_minimum: 990000,
          swap_type: "exact_input",
          network: "mainnet"
        })

      assert is_binary(result.calldata)
      assert String.starts_with?(result.calldata, "0x")
      assert result.swap_type == "exact_input"
      assert is_binary(result.to)
    end

    test "successfully encodes exact_output swap" do
      {:ok, result} =
        ExecuteSwap.run(%{
          token_in: @test_token_a,
          token_out: @test_token_b,
          fee: 3000,
          recipient: @recipient,
          amount_out: 1000000,
          amount_in_maximum: 1100000,
          swap_type: "exact_output",
          network: "mainnet"
        })

      assert is_binary(result.calldata)
      assert String.starts_with?(result.calldata, "0x")
      assert result.swap_type == "exact_output"
      assert is_binary(result.to)
    end
  end

  describe "AddLiquidity prism" do
    test "successfully encodes mint calldata" do
      {:ok, result} =
        AddLiquidity.run(%{
          token0: @test_token_a,
          token1: @test_token_b,
          fee: 3000,
          tick_lower: -120,
          tick_upper: 120,
          amount0_desired: 1000000000,
          amount1_desired: 2000000000,
          recipient: @recipient,
          network: "mainnet"
        })

      assert is_binary(result.calldata)
      assert String.starts_with?(result.calldata, "0x")
      assert is_binary(result.to)
    end
  end

  describe "RemoveLiquidity prism" do
    test "successfully encodes decreaseLiquidity calldata" do
      {:ok, result} =
        RemoveLiquidity.run(%{
          token_id: 12345,
          liquidity: 500000000,
          amount0_min: 100000,
          amount1_min: 200000,
          network: "mainnet"
        })

      assert is_binary(result.calldata)
      assert String.starts_with?(result.calldata, "0x")
      assert is_binary(result.to)
    end
  end

  describe "CollectFees prism" do
    test "successfully encodes collect calldata" do
      {:ok, result} =
        CollectFees.run(%{
          token_id: 12345,
          recipient: @recipient,
          network: "mainnet"
        })

      assert is_binary(result.calldata)
      assert String.starts_with?(result.calldata, "0x")
      assert is_binary(result.to)
    end
  end
end
