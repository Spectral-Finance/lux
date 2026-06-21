defmodule Lux.Lenses.Hyperliquid.GetAccountStateTest do
  @moduledoc """
  Test suite for the GetAccountState lens.
  """

  use UnitAPICase, async: true

  alias Lux.Lenses.Hyperliquid.GetAccountState

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully fetches and transforms account state" do
      test_address = "0x0403369c02199a0cb827f4d6492927e9fa5668d5"

      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["type"] == "clearinghouseState"
        assert decoded["user"] == test_address

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "crossMarginSummary" => %{
            "accountValue" => "10000.0",
            "totalMarginUsed" => "1000.0",
            "totalNtlPos" => "2000.0",
            "totalRawUsd" => "10000.0"
          },
          "crossMaintenanceMarginRatio" => "0.0625",
          "withdrawable" => "8000.0",
          "assetPositions" => [
            %{
              "type" => "cross",
              "position" => %{
                "coin" => "ETH",
                "szi" => "1.0",
                "entryPx" => "2800.0",
                "leverage" => 5.0,
                "liquidationPx" => "1400.0",
                "unrealizedPnl" => "100.0",
                "marginUsed" => "560.0",
                "positionValue" => "2800.0",
                "returnOnEquity" => "0.1786"
              }
            }
          ]
        }))
      end)

      assert {:ok, result} = GetAccountState.focus(%{address: test_address}, %{})
      assert result.margin_summary.account_value == "10000.0"
      assert result.margin_summary.total_margin_used == "1000.0"
      assert result.cross_maintenance_margin_ratio == "0.0625"
      assert result.withdrawable == "8000.0"

      assert length(result.asset_positions) == 1
      eth_pos = hd(result.asset_positions)
      assert eth_pos.coin == "ETH"
      assert eth_pos.size == "1.0"
      assert eth_pos.entry_px == "2800.0"
      assert eth_pos.leverage == %{type: "cross", value: 5.0}
      assert eth_pos.liquidation_px == "1400.0"
    end

    test "handles API error response" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "Internal error"}))
      end)

      assert {:error, _} = GetAccountState.focus(%{address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"}, %{})
    end
  end

  describe "schema validation" do
    test "validates required parameters" do
      lens = GetAccountState.view()
      assert "address" in lens.schema.required
    end
  end
end
