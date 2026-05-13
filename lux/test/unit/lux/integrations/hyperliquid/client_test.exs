defmodule Lux.Integrations.Hyperliquid.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Hyperliquid.Client

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "info helpers" do
    test "calls clearinghouseState with normalized user address" do
      Req.Test.expect(HyperliquidClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/info"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        assert payload["type"] == "clearinghouseState"
        assert payload["user"] == "0x0000000000000000000000000000000000000001"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "crossMarginSummary" => %{"accountValue" => "1000"},
            "assetPositions" => []
          })
        )
      end)

      assert {:ok, %{"crossMarginSummary" => %{"accountValue" => "1000"}}} =
               Client.clearinghouse_state(
                 "0x0000000000000000000000000000000000000001",
                 plug: {Req.Test, HyperliquidClientMock}
               )
    end

    test "calls l2Book for a perpetual coin" do
      Req.Test.expect(HyperliquidClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        assert payload["type"] == "l2Book"
        assert payload["coin"] == "ETH"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"coin" => "ETH", "levels" => [[], []]}))
      end)

      assert {:ok, %{"coin" => "ETH"}} =
               Client.l2_book("ETH", plug: {Req.Test, HyperliquidClientMock})
    end

    test "normalizes API errors" do
      Req.Test.expect(HyperliquidClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(422, Jason.encode!(%{"error" => "invalid request"}))
      end)

      assert {:error, {422, "invalid request"}} =
               Client.info(%{type: "unknown"}, plug: {Req.Test, HyperliquidClientMock})
    end
  end
end
