defmodule Lux.Lenses.Hyperliquid.GetPositionsTest do
  @moduledoc """
  Test suite for the GetPositions lens.
  """

  use UnitAPICase, async: true

  alias Lux.Lenses.Hyperliquid.GetPositions

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully fetches and transforms open positions" do
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
                "returnOnEquity" => "0.1786",
                "maxLeverage" => 50
              }
            }
          ]
        }))
      end)

      assert {:ok, result} = GetPositions.focus(%{address: test_address}, %{})
      assert length(result.positions) == 1
      eth_pos = hd(result.positions)
      assert eth_pos.coin == "ETH"
      assert eth_pos.size == "1.0"
      assert eth_pos.entry_px == "2800.0"
      assert eth_pos.leverage == %{type: "cross", value: 5.0}
      assert eth_pos.liquidation_px == "1400.0"
      assert eth_pos.max_leverage == 50
    end

    test "handles API error response" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "Internal error"}))
      end)

      assert {:error, _} = GetPositions.focus(%{address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"}, %{})
    end
  end

  describe "schema validation" do
    test "validates required parameters" do
      lens = GetPositions.view()
      assert "address" in lens.schema.required
    end
  end
end
