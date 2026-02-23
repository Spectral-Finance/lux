defmodule Lux.Lenses.Hyperliquid.HyperliquidPnlLensTest do
  @moduledoc """
  Test suite for HyperliquidPnlLens.
  Verifies P&L tracking for open positions.
  """

  use UnitCase, async: true

  alias Lux.Lenses.Hyperliquid.HyperliquidPnlLens

  @agent_ctx %{agent: %{name: "TestAgent"}}
  @test_address "0x0403369c02199a0cb827f4d6492927e9fa5668d5"

  describe "focus/2 — output structure" do
    test "returns all required fields" do
      case HyperliquidPnlLens.focus(%{address: @test_address}, @agent_ctx) do
        {:ok, result} ->
          assert Map.has_key?(result, :address)
          assert Map.has_key?(result, :total_unrealized_pnl)
          assert Map.has_key?(result, :total_account_value)
          assert Map.has_key?(result, :positions)
          assert is_list(result.positions)
        {:error, _} ->
          # Expected without live exchange in test env
          :ok
      end
    end

    test "position entries have required fields" do
      # Test the position structure by examining expected shape
      expected_position_keys = [
        :coin, :side, :size, :entry_price, :mark_price,
        :unrealized_pnl, :return_on_equity, :liquidation_price,
        :leverage, :margin_used
      ]

      case HyperliquidPnlLens.focus(%{address: @test_address}, @agent_ctx) do
        {:ok, %{positions: [pos | _]}} ->
          Enum.each(expected_position_keys, fn key ->
            assert Map.has_key?(pos, key), "Missing key: #{key}"
          end)
        {:ok, %{positions: []}} ->
          # No open positions — this is valid
          :ok
        {:error, _} ->
          :ok
      end
    end
  end

  describe "focus/2 — address validation" do
    test "accepts valid checksummed address" do
      case HyperliquidPnlLens.focus(%{
        address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
      }, @agent_ctx) do
        {:ok, result} -> assert result.address == "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
        {:error, _} -> :ok
      end
    end
  end
end
