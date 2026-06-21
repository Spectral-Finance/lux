defmodule Lux.Lenses.Hyperliquid.GetOrderBookTest do
  @moduledoc """
  Test suite for the GetOrderBook lens.
  """

  use UnitAPICase, async: true

  alias Lux.Lenses.Hyperliquid.GetOrderBook

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully fetches and transforms order book data" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["type"] == "l2Book"
        assert decoded["coin"] == "ETH"
        assert decoded["depth"] == 10

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "coin" => "ETH",
          "levels" => [
            [
              [%{"px" => "2799.0", "sz" => "10.5", "n" => 3}],
              [%{"px" => "2801.0", "sz" => "8.2", "n" => 2}]
            ]
          ]
        }))
      end)

      assert {:ok, result} = GetOrderBook.focus(%{coin: "ETH", depth: 10}, %{})
      assert length(result.levels) == 1
      level = hd(result.levels)
      assert length(level.bids) == 1
      assert length(level.asks) == 1

      bid = hd(level.bids)
      assert bid.px == "2799.0"
      assert bid.sz == "10.5"
      assert bid.n == 3

      ask = hd(level.asks)
      assert ask.px == "2801.0"
      assert ask.sz == "8.2"
      assert ask.n == 2
    end

    test "handles API error response" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "Internal error"}))
      end)

      assert {:error, _} = GetOrderBook.focus(%{coin: "ETH"}, %{})
    end
  end

  describe "schema validation" do
    test "validates required parameters" do
      lens = GetOrderBook.view()
      assert "coin" in lens.schema.required
    end
  end
end
