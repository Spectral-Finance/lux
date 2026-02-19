defmodule Lux.Integrations.Binance.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Binance.Client

  setup do
    Req.Test.verify_on_exit!()
    Application.put_env(:lux, :api_keys,
      binance_api_key: "test-api-key",
      binance_secret_key: "test-secret-key"
    )
    :ok
  end

  describe "request/4 public endpoints" do
    test "makes successful GET request" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v3/ticker/price"

        query = URI.decode_query(conn.query_string)
        assert query["symbol"] == "BTCUSDT"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "symbol" => "BTCUSDT",
          "price" => "42000.00"
        }))
      end)

      assert {:ok, %{"symbol" => "BTCUSDT", "price" => "42000.00"}} =
               Client.request(:get, "/api/v3/ticker/price", %{symbol: "BTCUSDT"},
                 plug: {Req.Test, Lux.Integrations.Binance.Client}
               )
    end

    test "handles 429 rate limiting" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{
          "code" => -1015,
          "msg" => "Too many requests"
        }))
      end)

      assert {:error, {:rate_limited, _}} =
               Client.request(:get, "/api/v3/ticker/price", %{symbol: "BTCUSDT"},
                 plug: {Req.Test, Lux.Integrations.Binance.Client}
               )
    end

    test "handles 418 IP ban" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(418, Jason.encode!(%{
          "code" => -1003,
          "msg" => "Way too many requests; IP has been auto-banned"
        }))
      end)

      assert {:error, {:ip_banned, _}} =
               Client.request(:get, "/api/v3/ticker/price", %{symbol: "BTCUSDT"},
                 plug: {Req.Test, Lux.Integrations.Binance.Client}
               )
    end

    test "handles API error with code and message" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "code" => -1121,
          "msg" => "Invalid symbol."
        }))
      end)

      assert {:error, {400, -1121, "Invalid symbol."}} =
               Client.request(:get, "/api/v3/ticker/price", %{symbol: "INVALID"},
                 plug: {Req.Test, Lux.Integrations.Binance.Client}
               )
    end
  end

  describe "request/4 signed endpoints" do
    test "makes signed POST request with API key header" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v3/order"

        api_key_headers = Plug.Conn.get_req_header(conn, "x-mbx-apikey")
        assert api_key_headers == ["test-api-key"]

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        params = URI.decode_query(body)
        assert params["symbol"] == "BTCUSDT"
        assert params["side"] == "BUY"
        assert Map.has_key?(params, "timestamp")
        assert Map.has_key?(params, "signature")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "orderId" => 123456,
          "symbol" => "BTCUSDT",
          "status" => "FILLED",
          "side" => "BUY",
          "type" => "MARKET"
        }))
      end)

      assert {:ok, %{"orderId" => 123456}} =
               Client.request(:post, "/api/v3/order", %{
                 symbol: "BTCUSDT",
                 side: "BUY",
                 type: "MARKET",
                 quantity: "0.001"
               }, signed: true, plug: {Req.Test, Lux.Integrations.Binance.Client})
    end

    test "makes signed DELETE request" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v3/order"

        api_key_headers = Plug.Conn.get_req_header(conn, "x-mbx-apikey")
        assert api_key_headers == ["test-api-key"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "orderId" => 123456,
          "symbol" => "BTCUSDT",
          "status" => "CANCELED"
        }))
      end)

      assert {:ok, %{"status" => "CANCELED"}} =
               Client.request(:delete, "/api/v3/order", %{
                 symbol: "BTCUSDT",
                 orderId: 123456
               }, signed: true, plug: {Req.Test, Lux.Integrations.Binance.Client})
    end
  end

  describe "base_url/1" do
    test "returns spot endpoint" do
      assert Client.base_url(:spot) == "https://api.binance.com"
    end

    test "returns futures endpoint" do
      assert Client.base_url(:futures) == "https://fapi.binance.com"
    end
  end
end
