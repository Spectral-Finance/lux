defmodule Lux.Prisms.Hyperliquid.HyperliquidExecuteOrderPrismTest do
  @moduledoc """
  Test suite for HyperliquidExecuteOrderPrism.
  """

  use UnitAPICase, async: false

  import Mock

  alias Lux.Prisms.Hyperliquid.HyperliquidExecuteOrderPrism

  describe "run/1" do
    test "successfully executes an order" do
      input = %{
        "coin" => "ETH",
        "is_buy" => true,
        "sz" => 0.05,
        "limit_px" => 2800.0,
        "order_type" => %{"limit" => %{"tif" => "Gtc"}},
        "reduce_only" => false
      }

      with_mocks([
        {Lux.Config, [], [
          hyperliquid_account_key: fn -> "0x" <> String.duplicate("1", 64) end,
          hyperliquid_account_address: fn -> "0x0403369c02199a0cb827f4d6492927e9fa5668d5" end,
          hyperliquid_api_url: fn -> "https://api.hyperliquid.xyz" end
        ]},
        {Lux.Python, [], [
          import_package: fn _pkg -> {:ok, %{"success" => true}} end,
          eval!: fn _code, _opts ->
            %{"status" => "success", "order_id" => 987_654}
          end
        ]}
      ]) do
        assert {:ok, response} = HyperliquidExecuteOrderPrism.run(input)
        assert response.status == "success"
        assert response.order_result["status"] == "success"
        assert response.order_result["order_id"] == 987_654
      end
    end
  end
end
