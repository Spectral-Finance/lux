defmodule Lux.Lenses.Coinbase.FeesLensTest do
  @moduledoc """
  Test suite for the Coinbase Fees lens.
  """

  use UnitAPICase, async: true

  alias Lux.Lenses.Coinbase.FeesLens

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "after_focus/1" do
    test "successfully parses transaction summary response" do
      response = %{
        "total_volume" => 50000.0,
        "total_fees" => 125.0,
        "fee_tier" => %{
          "pricing_tier" => "Advanced",
          "maker_fee_rate" => "0.004",
          "taker_fee_rate" => "0.006"
        },
        "margin_rate" => %{"value" => "0.05"},
        "goods_and_services_tax" => nil,
        "advanced_trade_only_volume" => 45000.0,
        "advanced_trade_only_fees" => 110.0,
        "coinbase_pro_volume" => 5000.0,
        "coinbase_pro_fees" => 15.0
      }

      assert {:ok, result} = FeesLens.after_focus(response)
      assert result.total_volume == 50000.0
      assert result.total_fees == 125.0
      assert result.fee_tier["pricing_tier"] == "Advanced"
      assert result.fee_tier["maker_fee_rate"] == "0.004"
      assert result.fee_tier["taker_fee_rate"] == "0.006"
      assert result.advanced_trade_only_volume == 45000.0
      assert result.coinbase_pro_volume == 5000.0
    end

    test "handles error response" do
      assert {:error, "Unauthorized"} =
               FeesLens.after_focus(%{"error" => "Unauthorized"})
    end
  end
end
