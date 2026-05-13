defmodule Lux.Integrations.SushiSwap.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.SushiSwap.Client

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "quote/3" do
    test "calls Sushi quote API with chain id and referrer" do
      Req.Test.expect(SushiSwapClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/quote/v7/1"

        query = URI.decode_query(conn.query_string)
        assert query["tokenIn"] == "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
        assert query["tokenOut"] == "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
        assert query["amount"] == "1000000000000000000"
        assert query["referrer"] == "lux-test"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "status" => "Success",
            "amountIn" => "1000000000000000000",
            "assumedAmountOut" => "2300000000"
          })
        )
      end)

      assert {:ok, %{"status" => "Success"}} =
               Client.quote(
                 :ethereum,
                 %{
                   tokenIn: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
                   tokenOut: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                   amount: "1000000000000000000"
                 },
                 referrer: "lux-test",
                 plug: {Req.Test, SushiSwapClientMock}
               )
    end

    test "normalizes Sushi validation errors" do
      Req.Test.expect(SushiSwapClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          422,
          Jason.encode!(%{
            "title" => "Validation Error",
            "errors" => [%{"parameter" => "tokenIn"}]
          })
        )
      end)

      assert {:error, {422, "Validation Error", [%{"parameter" => "tokenIn"}]}} =
               Client.quote(:ethereum, %{}, plug: {Req.Test, SushiSwapClientMock})
    end
  end

  describe "token/3" do
    test "fetches token metadata" do
      Req.Test.expect(SushiSwapClientMock, fn conn ->
        assert conn.request_path == "/token/v1/1/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"symbol" => "USDC", "decimals" => 6}))
      end)

      assert {:ok, %{"symbol" => "USDC", "decimals" => 6}} =
               Client.token(
                 1,
                 "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
                 plug: {Req.Test, SushiSwapClientMock}
               )
    end
  end
end
