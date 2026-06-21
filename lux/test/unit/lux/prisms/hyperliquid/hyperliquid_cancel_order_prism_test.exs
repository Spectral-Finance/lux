defmodule Lux.Prisms.HyperliquidCancelOrderPrismTest do
  @moduledoc """
  Test suite for HyperliquidCancelOrderPrism.
  """

  use UnitAPICase, async: false

  import Mock

  alias Lux.Prisms.HyperliquidCancelOrderPrism

  describe "run/1" do
    test "successfully cancels an order" do
      input = %{
        "coin" => "ETH",
        "order_id" => 123_456
      }

      with_mocks([
        {Lux.Config, [], [
          hyperliquid_account_key: fn -> "0x" <> String.duplicate("1", 64) end,
          hyperliquid_account_address: fn -> "0x0403369c02199a0cb827f4d6492927e9fa5668d5" end,
          hyperliquid_api_url: fn -> "https://api.hyperliquid.xyz" end
        ]},
        {Lux.Python, [], [
          import_package: fn _pkg -> {:ok, %{"success" => true}} end,
          eval!: fn _code, opts ->
            vars = Keyword.get(opts, :variables, %{})
            params = Map.get(vars, :params)
            %{
              "coin" => params["coin"],
              "order_id" => params["order_id"],
              "result" => %{"status" => "success"}
            }
          end
        ]}
      ]) do
        assert {:ok, response} = HyperliquidCancelOrderPrism.run(input)
        assert response.status == "success"
        assert response.cancelled_order["coin"] == "ETH"
        assert response.cancelled_order["order_id"] == 123_456
      end
    end
  end
end
