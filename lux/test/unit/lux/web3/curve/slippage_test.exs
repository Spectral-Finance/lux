defmodule Lux.Web3.Curve.SlippageTest do
  @moduledoc false
  use UnitCase, async: true

  alias Lux.Web3.Curve.Slippage

  describe "happy path: slippage optimisation" do
    test "min_received/2 applies a tolerance in basis points" do
      assert {:ok, 995_000} = Slippage.min_received(1_000_000, 50)
    end

    test "price_impact_bps/2 measures realised slippage" do
      assert {:ok, 100} = Slippage.price_impact_bps(1_000, 990)
    end

    test "acceptable?/2 accepts output at or above the minimum" do
      assert Slippage.acceptable?(995_000, 995_000)
    end
  end

  describe "null input: handled with a typed validation error" do
    test "min_received/2 rejects a null quote" do
      assert {:error, :invalid_quote} = Slippage.min_received(nil, 50)
    end

    test "acceptable?/2 returns false for null arguments" do
      refute Slippage.acceptable?(nil, 1)
    end

    test "price_impact_bps/2 rejects null amounts" do
      assert {:error, :invalid_amounts} = Slippage.price_impact_bps(nil, 1)
    end
  end

  describe "empty input: rejected with a clear diagnostic" do
    test "min_received/2 rejects a non-integer tolerance" do
      assert {:error, :invalid_quote} = Slippage.min_received(1_000, "")
    end

    test "price_impact_bps/2 rejects an undefined price" do
      assert {:error, :invalid_amounts} = Slippage.price_impact_bps(0, 0)
    end
  end

  describe "boundary limits: strict half-open evaluation" do
    test "a zero tolerance returns the full quote at the lower bound" do
      assert {:ok, 1_000} = Slippage.min_received(1_000, 0)
    end

    test "a maximum tolerance returns zero at the upper bound" do
      assert {:ok, 0} = Slippage.min_received(1_000, 10_000)
    end

    test "a zero quote yields zero at the lower bound" do
      assert {:ok, 0} = Slippage.min_received(0, 5_000)
    end

    test "price impact of exactly zero is allowed at the lower bound" do
      assert {:ok, 0} = Slippage.price_impact_bps(1_000, 1_000)
    end
  end

  describe "negative: malformed inputs are refused" do
    test "a tolerance above 100% is refused" do
      assert {:error, :invalid_tolerance} = Slippage.min_received(1_000, 10_001)
    end

    test "a negative quote is refused" do
      assert {:error, :invalid_quote} = Slippage.min_received(-1, 50)
    end

    test "an actual output above the expected output is refused" do
      assert {:error, :amount_exceeds_expected} = Slippage.price_impact_bps(1_000, 1_001)
    end

    test "a negative actual output is refused" do
      assert {:error, :invalid_amounts} = Slippage.price_impact_bps(1_000, -1)
    end
  end

  describe "concurrency: simultaneous slippage computation" do
    test "concurrent min_received/2 calls are consistent" do
      results =
        1..20
        |> Enum.map(fn _ -> Task.async(fn -> Slippage.min_received(1_000_000, 50) end) end)
        |> Task.await_many(30_000)

      assert length(Enum.uniq(results)) == 1
      assert Enum.all?(results, &(&1 == {:ok, 995_000}))
    end
  end
end
