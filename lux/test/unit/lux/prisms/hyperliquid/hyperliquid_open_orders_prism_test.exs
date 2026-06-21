defmodule Lux.Prisms.Hyperliquid.HyperliquidOpenOrdersPrismTest do
  @moduledoc """
  Test suite for HyperliquidOpenOrdersPrism.
  """

  use UnitAPICase, async: false

  import Mock

  alias Lux.Prisms.Hyperliquid.HyperliquidOpenOrdersPrism

  describe "run/1" do
    test "successfully fetches open orders" do
      input = %{
        address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
      }

      with_mocks([
        {Lux.Config, [], [
          hyperliquid_account_key: fn -> "0x" <> String.duplicate("1", 64) end,
          hyperliquid_api_url: fn -> "https://api.hyperliquid.xyz" end
        ]},
        {Lux.Python, [], [
          import_package: fn _pkg -> {:ok, %{"success" => true}} end,
          eval!: fn _code, _opts ->
            [
              %{
                "coin" => "ETH",
                "oid" => 123_456,
                "sz" => "0.1",
                "limit_px" => "2800.0",
                "order_type" => %{"limit" => %{"tif" => "Gtc"}},
                "side" => "B",
                "timestamp" => 1_678_901_234_567
              }
            ]
          end
        ]}
      ]) do
        assert {:ok, response} = HyperliquidOpenOrdersPrism.run(input)
        assert response.status == "success"
        assert length(response.open_orders) == 1
        order = hd(response.open_orders)
        assert order["coin"] == "ETH"
        assert order["oid"] == 123_456
        assert order["side"] == "B"
      end
    end
  end
end
