defmodule Lux.Prisms.Hyperliquid.ModifyOrderPrismTest do
  @moduledoc """
  Test suite for ModifyOrderPrism.
  """

  use UnitAPICase, async: false

  import Mock

  alias Lux.Prisms.Hyperliquid.ModifyOrderPrism

  describe "run/1" do
    test "successfully modifies an order" do
      input = %{
        "coin" => "ETH",
        "order_id" => 123_456,
        "is_buy" => true,
        "sz" => 0.1,
        "limit_px" => 2850.0,
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
          eval!: fn _code, opts ->
            vars = Keyword.get(opts, :variables, %{})
            params = Map.get(vars, :params)
            %{
              "coin" => params["coin"],
              "order_id" => params["order_id"],
              "result" => %{"status" => "filled"}
            }
          end
        ]}
      ]) do
        assert {:ok, response} = ModifyOrderPrism.run(input)
        assert response.status == "success"
        assert response.modified_order["coin"] == "ETH"
        assert response.modified_order["order_id"] == 123_456
      end
    end

    test "returns error when private key is missing" do
      input = %{
        "coin" => "ETH",
        "order_id" => 123_456,
        "is_buy" => true,
        "sz" => 0.1,
        "limit_px" => 2850.0,
        "order_type" => %{"limit" => %{"tif" => "Gtc"}},
        "reduce_only" => false
      }

      with_mocks([
        {Lux.Config, [], [
          hyperliquid_account_key: fn -> raise RuntimeError, "not configured" end,
          hyperliquid_account_address: fn -> "0x0403369c02199a0cb827f4d6492927e9fa5668d5" end,
          hyperliquid_api_url: fn -> "https://api.hyperliquid.xyz" end
        ]}
      ]) do
        assert {:error, reason} = ModifyOrderPrism.run(input)
        assert String.contains?(reason, "private key is not configured")
      end
    end
  end
end
