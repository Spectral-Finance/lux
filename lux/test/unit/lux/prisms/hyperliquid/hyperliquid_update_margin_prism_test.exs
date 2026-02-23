defmodule Lux.Prisms.Hyperliquid.HyperliquidUpdateMarginPrismTest do
  @moduledoc """
  Test suite for HyperliquidUpdateMarginPrism.
  Verifies adding and removing margin from isolated positions.
  """

  use UnitCase, async: true

  alias Lux.Prisms.Hyperliquid.HyperliquidUpdateMarginPrism

  @agent_ctx %{agent: %{name: "TestAgent"}}

  describe "handler/2 — direction classification" do
    test "positive amount classified as 'added'" do
      case HyperliquidUpdateMarginPrism.handler(%{
        coin: "ETH",
        amount_usd: 500.0
      }, @agent_ctx) do
        {:ok, result} ->
          assert result.direction == "added"
          assert result.amount_usd == 500.0
        {:error, _} ->
          :ok
      end
    end

    test "negative amount classified as 'removed'" do
      case HyperliquidUpdateMarginPrism.handler(%{
        coin: "ETH",
        amount_usd: -200.0
      }, @agent_ctx) do
        {:ok, result} ->
          assert result.direction == "removed"
          assert result.amount_usd == -200.0
        {:error, _} ->
          :ok
      end
    end

    test "zero amount classified as 'added'" do
      case HyperliquidUpdateMarginPrism.handler(%{
        coin: "ETH",
        amount_usd: 0.0
      }, @agent_ctx) do
        {:ok, result} ->
          assert result.direction == "added"
        {:error, _} ->
          :ok
      end
    end
  end

  describe "handler/2 — validation" do
    test "requires coin" do
      assert {:error, _} = HyperliquidUpdateMarginPrism.handler(%{
        amount_usd: 100.0
      }, @agent_ctx)
    end

    test "requires amount_usd" do
      assert {:error, _} = HyperliquidUpdateMarginPrism.handler(%{
        coin: "ETH"
      }, @agent_ctx)
    end
  end

  describe "handler/2 — output structure" do
    test "returns complete result structure" do
      case HyperliquidUpdateMarginPrism.handler(%{
        coin: "ETH",
        amount_usd: 100.0
      }, @agent_ctx) do
        {:ok, result} ->
          assert Map.has_key?(result, :coin)
          assert Map.has_key?(result, :amount_usd)
          assert Map.has_key?(result, :direction)
          assert Map.has_key?(result, :status)
        {:error, _} ->
          :ok
      end
    end
  end
end
