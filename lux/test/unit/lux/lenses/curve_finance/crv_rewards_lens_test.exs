defmodule Lux.Lenses.CurveFinance.CrvRewardsLensTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.CurveFinance.CrvRewardsLens

  describe "run/1" do
    test "tracks rewards for single gauge" do
      params = %{wallet: "0x1234567890abcdef1234567890abcdef12345678", gauge: "0xbBC81d23Ea2c3ec7e56D39693049825d3f869366"}
      assert {:ok, result} = CrvRewardsLens.run(params)
      assert result.rewards.pending_crv > 0
      assert result.rewards.claimable == true
    end

    test "tracks rewards across all gauges" do
      params = %{wallet: "0x1234567890abcdef1234567890abcdef12345678", all_gauges: true}
      assert {:ok, result} = CrvRewardsLens.run(params)
      assert result.total_pending_crv > 0
      assert length(result.gauges) > 0
    end

    test "returns error for invalid parameters" do
      assert {:error, :invalid_parameters} = CrvRewardsLens.run(%{})
    end
  end
end
