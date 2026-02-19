defmodule Lux.Integrations.Coinbase.ClientTest do
  @moduledoc """
  Test suite for the Coinbase API client.
  Tests cover:
  - JWT generation
  - API request handling
  - Error handling
  - Rate limit handling
  - DER signature conversion
  """

  use UnitAPICase, async: false

  alias Lux.Integrations.Coinbase.Client

  setup do
    Req.Test.verify_on_exit!()

    # Ensure Coinbase API keys are configured for tests
    Application.put_env(:lux, :api_keys,
      Keyword.merge(
        Application.get_env(:lux, :api_keys, []),
        [
          coinbase_api_key: "organizations/test-org/apiKeys/test-key-id",
          coinbase_api_secret: test_ec_private_key()
        ]
      )
    )

    :ok
  end

  describe "request/3" do
    test "successfully makes a GET request" do
      Req.Test.expect(CoinbaseClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v3/brokerage/accounts"

        # Verify JWT auth header is present
        [auth_header] = Plug.Conn.get_req_header(conn, "authorization")
        assert String.starts_with?(auth_header, "Bearer ")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "accounts" => [
            %{
              "uuid" => "test-uuid",
              "name" => "BTC Wallet",
              "currency" => "BTC",
              "available_balance" => %{"value" => "1.5", "currency" => "BTC"}
            }
          ]
        }))
      end)

      assert {:ok, %{"accounts" => [account]}} =
               Client.request(:get, "/accounts", %{plug: {Req.Test, CoinbaseClientMock}})

      assert account["uuid"] == "test-uuid"
      assert account["currency"] == "BTC"
    end

    test "successfully makes a POST request with JSON body" do
      Req.Test.expect(CoinbaseClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v3/brokerage/orders"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["product_id"] == "BTC-USD"
        assert decoded["side"] == "BUY"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "success" => true,
          "order_id" => "test-order-123"
        }))
      end)

      assert {:ok, %{"success" => true, "order_id" => "test-order-123"}} =
               Client.request(:post, "/orders", %{
                 json: %{product_id: "BTC-USD", side: "BUY"},
                 plug: {Req.Test, CoinbaseClientMock}
               })
    end

    test "handles 401 unauthorized error" do
      Req.Test.expect(CoinbaseClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{"message" => "Unauthorized"}))
      end)

      assert {:error, :invalid_credentials} =
               Client.request(:get, "/accounts", %{plug: {Req.Test, CoinbaseClientMock}})
    end

    test "handles 403 forbidden error" do
      Req.Test.expect(CoinbaseClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Forbidden"}))
      end)

      assert {:error, :forbidden} =
               Client.request(:get, "/accounts", %{plug: {Req.Test, CoinbaseClientMock}})
    end

    test "handles 429 rate limit error" do
      Req.Test.expect(CoinbaseClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("retry-after", "30")
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{"message" => "Rate limited"}))
      end)

      assert {:error, {:rate_limited, 30}} =
               Client.request(:get, "/accounts", %{plug: {Req.Test, CoinbaseClientMock}})
    end

    test "handles API error with message" do
      Req.Test.expect(CoinbaseClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "error" => "INVALID_REQUEST",
          "message" => "Invalid product_id"
        }))
      end)

      assert {:error, {400, "INVALID_REQUEST: Invalid product_id"}} =
               Client.request(:get, "/products/INVALID", %{plug: {Req.Test, CoinbaseClientMock}})
    end
  end

  describe "generate_jwt/2" do
    test "generates a valid JWT structure" do
      assert {:ok, jwt} = Client.generate_jwt("GET", "/api/v3/brokerage/accounts")

      # JWT should have three parts separated by dots
      parts = String.split(jwt, ".")
      assert length(parts) == 3

      # Decode and verify header
      header = parts |> Enum.at(0) |> Base.url_decode64!(padding: false) |> Jason.decode!()
      assert header["alg"] == "ES256"
      assert header["typ"] == "JWT"
      assert header["kid"] == "organizations/test-org/apiKeys/test-key-id"
      assert is_binary(header["nonce"])

      # Decode and verify payload
      payload = parts |> Enum.at(1) |> Base.url_decode64!(padding: false) |> Jason.decode!()
      assert payload["iss"] == "cdp"
      assert payload["sub"] == "organizations/test-org/apiKeys/test-key-id"
      assert payload["uri"] == "GET api.coinbase.com/api/v3/brokerage/accounts"
      assert is_integer(payload["nbf"])
      assert is_integer(payload["exp"])
      assert payload["exp"] - payload["nbf"] == 120
    end

    test "generates unique nonces for each JWT" do
      {:ok, jwt1} = Client.generate_jwt("GET", "/api/v3/brokerage/accounts")
      {:ok, jwt2} = Client.generate_jwt("GET", "/api/v3/brokerage/accounts")

      header1 =
        jwt1 |> String.split(".") |> Enum.at(0) |> Base.url_decode64!(padding: false) |> Jason.decode!()

      header2 =
        jwt2 |> String.split(".") |> Enum.at(0) |> Base.url_decode64!(padding: false) |> Jason.decode!()

      assert header1["nonce"] != header2["nonce"]
    end

    test "includes correct URI for different methods and paths" do
      {:ok, jwt_get} = Client.generate_jwt("GET", "/api/v3/brokerage/products")

      payload =
        jwt_get |> String.split(".") |> Enum.at(1) |> Base.url_decode64!(padding: false) |> Jason.decode!()

      assert payload["uri"] == "GET api.coinbase.com/api/v3/brokerage/products"

      {:ok, jwt_post} = Client.generate_jwt("POST", "/api/v3/brokerage/orders")

      payload_post =
        jwt_post |> String.split(".") |> Enum.at(1) |> Base.url_decode64!(padding: false) |> Jason.decode!()

      assert payload_post["uri"] == "POST api.coinbase.com/api/v3/brokerage/orders"
    end

    test "returns error when API key is missing" do
      original = Application.get_env(:lux, :api_keys)

      Application.put_env(
        :lux,
        :api_keys,
        Keyword.delete(original, :coinbase_api_key)
      )

      assert {:error, :missing_api_key} = Client.generate_jwt("GET", "/api/v3/brokerage/accounts")

      Application.put_env(:lux, :api_keys, original)
    end

    test "returns error when API secret is missing" do
      original = Application.get_env(:lux, :api_keys)

      Application.put_env(
        :lux,
        :api_keys,
        Keyword.delete(original, :coinbase_api_secret)
      )

      assert {:error, :missing_api_secret} = Client.generate_jwt("GET", "/api/v3/brokerage/accounts")

      Application.put_env(:lux, :api_keys, original)
    end
  end

  # Generate a valid test EC private key for ES256
  defp test_ec_private_key do
    # Generate a real EC key for testing
    ec_key = :public_key.generate_key({:namedCurve, :secp256r1})
    pem_entry = :public_key.pem_entry_encode(:ECPrivateKey, ec_key)
    :public_key.pem_encode([pem_entry])
  end
end
