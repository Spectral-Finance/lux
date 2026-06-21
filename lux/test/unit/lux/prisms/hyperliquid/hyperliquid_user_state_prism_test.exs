defmodule Lux.Prisms.Hyperliquid.HyperliquidUserStatePrismTest do
  @moduledoc """
  Test suite for HyperliquidUserStatePrism.
  """

  use UnitAPICase, async: false

  import Mock

  alias Lux.Prisms.Hyperliquid.HyperliquidUserStatePrism

  describe "run/1" do
    test "successfully fetches user state" do
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
            %{
              "crossMaintenanceMarginRatio" => "0.0625",
              "crossMarginSummary" => %{
                "accountValue" => "10000.0",
                "totalMarginUsed" => "1000.0",
                "totalNtlPos" => "2000.0",
                "totalRawUsd" => "10000.0"
              },
              "assetPositions" => [
                %{
                  "coin" => "ETH",
                  "position" => %{
                    "entryPx" => "2800.0",
                    "leverage" => "2.0",
                    "liquidationPx" => "1400.0",
                    "marginUsed" => "1000.0",
                    "positionValue" => "2000.0",
                    "returnOnEquity" => "0.15",
                    "size" => "1.0"
                  }
                }
              ]
            }
          end
        ]}
      ]) do
        assert {:ok, response} = HyperliquidUserStatePrism.run(input)
        assert response.status == "success"
        assert response.user_state["crossMaintenanceMarginRatio"] == "0.0625"
        assert response.user_state["crossMarginSummary"]["accountValue"] == "10000.0"
        assert length(response.user_state["assetPositions"]) == 1
        pos = hd(response.user_state["assetPositions"])
        assert pos["coin"] == "ETH"
        assert pos["position"]["entryPx"] == "2800.0"
      end
    end
  end
end
