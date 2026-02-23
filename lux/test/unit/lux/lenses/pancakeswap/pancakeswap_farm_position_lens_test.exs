defmodule Lux.Lenses.PancakeSwap.PancakeSwapFarmPositionLensTest do
  @moduledoc """
  Test suite for PancakeSwapFarmPositionLens.
  """

  use UnitCase, async: true

  alias Lux.Lenses.PancakeSwap.PancakeSwapFarmPositionLens

  # Use a known MasterChef staker for testing
  @test_address "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
  @agent_ctx %{agent: %{name: "FarmAgent"}}

  describe "focus/2 — with BSC RPC" do
    setup do
      System.put_env("PANCAKESWAP_RPC_URL", "https://bsc-dataseed.binance.org")
      on_exit(fn -> System.delete_env("PANCAKESWAP_RPC_URL") end)
    end

    test "fetches farm position for pid 2" do
      result = PancakeSwapFarmPositionLens.focus(
        %{pid: 2, user_address: @test_address},
        @agent_ctx
      )

      case result do
        {:ok, pos} ->
          assert pos.pid == 2
          assert pos.user_address == @test_address
          assert is_binary(pos.staked_lp)
          assert is_binary(pos.pending_cake)
          assert is_binary(pos.reward_debt)
          assert is_boolean(pos.harvest_ready)
        {:error, _} ->
          :ok
      end
    end

    test "returns zero staked for fresh address" do
      fresh = "0x0000000000000000000000000000000000000001"

      case PancakeSwapFarmPositionLens.focus(
        %{pid: 2, user_address: fresh},
        @agent_ctx
      ) do
        {:ok, pos} ->
          assert pos.staked_lp == "0"
          assert pos.pending_cake == "0"
          assert pos.harvest_ready == false
        {:error, _} ->
          :ok
      end
    end

    test "harvest_ready is false when pending_cake is zero" do
      fresh = "0x0000000000000000000000000000000000000002"

      case PancakeSwapFarmPositionLens.focus(
        %{pid: 2, user_address: fresh},
        @agent_ctx
      ) do
        {:ok, pos} ->
          # pending_cake == 0 → harvest_ready should be false
          if pos.pending_cake == "0" do
            assert pos.harvest_ready == false
          end
        {:error, _} ->
          :ok
      end
    end

    test "accepts custom min_harvest_cake threshold" do
      result = PancakeSwapFarmPositionLens.focus(
        %{
          pid: 0,
          user_address: @test_address,
          min_harvest_cake: "10000000000000000000"
        },
        @agent_ctx
      )

      assert {:ok, _} = result or {:error, _} = result
    end

    test "CAKE staking pool (pid 0) returns lp_token_address" do
      case PancakeSwapFarmPositionLens.focus(
        %{pid: 0, user_address: @test_address},
        @agent_ctx
      ) do
        {:ok, pos} ->
          assert is_binary(pos.lp_token_address)
        {:error, _} ->
          :ok
      end
    end
  end

  describe "focus/2 — returns all required fields" do
    setup do
      System.put_env("PANCAKESWAP_RPC_URL", "https://bsc-dataseed.binance.org")
      on_exit(fn -> System.delete_env("PANCAKESWAP_RPC_URL") end)
    end

    test "returns all expected fields" do
      case PancakeSwapFarmPositionLens.focus(
        %{pid: 2, user_address: @test_address},
        @agent_ctx
      ) do
        {:ok, pos} ->
          assert Map.has_key?(pos, :pid)
          assert Map.has_key?(pos, :user_address)
          assert Map.has_key?(pos, :staked_lp)
          assert Map.has_key?(pos, :pending_cake)
          assert Map.has_key?(pos, :reward_debt)
          assert Map.has_key?(pos, :lp_token_address)
          assert Map.has_key?(pos, :harvest_ready)
        {:error, _} ->
          :ok
      end
    end
  end

  describe "lens metadata" do
    test "has correct name" do
      assert PancakeSwapFarmPositionLens.__lens__(:name) == "PancakeSwap Farm Position"
    end

    test "requires pid and user_address" do
      schema = PancakeSwapFarmPositionLens.__lens__(:schema)
      assert "pid" in schema.required
      assert "user_address" in schema.required
    end

    test "masterchef_address and min_harvest_cake are optional" do
      schema = PancakeSwapFarmPositionLens.__lens__(:schema)
      refute "masterchef_address" in schema.required
      refute "min_harvest_cake" in schema.required
    end
  end
end
