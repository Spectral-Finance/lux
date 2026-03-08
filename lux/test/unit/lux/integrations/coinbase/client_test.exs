defmodule Lux.Integrations.Coinbase.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Coinbase.Client

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "request/3" do
    test "makes correct GET request with auth headers" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v3/brokerage/products"
        assert [_] = Plug.Conn.get_req_header(conn, "cb-access-key")
        assert [_] = Plug.Conn.get_req_header(conn, "cb-access-sign")
        assert [_] = Plug.Conn.get_req_header(conn, "cb-access-timestamp")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"products" => [%{"product_id" => "BTC-USD", "price" => "50000.00"}]}))
      end)

      assert {:ok, %{"products" => [%{"product_id" => "BTC-USD"}]}} =
               Client.request(:get, "/products", %{api_key: "test-key", api_secret: "test-secret", plug: {Req.Test, __MODULE__}})
    end

    test "makes correct POST request with JSON body" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert conn.method == "POST"
        assert params["product_id"] == "BTC-USD"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"success" => true, "order_id" => "order-123"}))
      end)

      assert {:ok, %{"success" => true}} =
               Client.request(:post, "/orders", %{api_key: "k", api_secret: "s", json: %{product_id: "BTC-USD"}, plug: {Req.Test, __MODULE__}})
    end

    test "handles 401 authentication error" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(401, Jason.encode!(%{"message" => "Unauthorized"}))
      end)

      assert {:error, :invalid_credentials} = Client.request(:get, "/accounts", %{api_key: "bad", api_secret: "bad", plug: {Req.Test, __MODULE__}})
    end

    test "handles 429 rate limiting" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(429, Jason.encode!(%{"message" => "Rate limit"}))
      end)

      assert {:error, :rate_limited} = Client.request(:get, "/products", %{api_key: "k", api_secret: "s", plug: {Req.Test, __MODULE__}})
    end

    test "handles API error with error and message" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(400, Jason.encode!(%{"error" => "INVALID", "message" => "Bad request"}))
      end)

      assert {:error, {400, "INVALID: Bad request"}} = Client.request(:get, "/products/X", %{api_key: "k", api_secret: "s", plug: {Req.Test, __MODULE__}})
    end
  end
end
