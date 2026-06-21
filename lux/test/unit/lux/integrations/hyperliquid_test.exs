defmodule Lux.Integrations.HyperliquidTest do
  @moduledoc """
  Test suite for the Hyperliquid integration module.
  Tests verify:
  - Configuration defaults and access
  - URL construction
  - Header generation
  - Info and exchange API request handling
  """

  use UnitAPICase, async: true

  alias Lux.Integrations.Hyperliquid

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "configuration" do
    test "base_url returns default URL when not configured" do
      url = Hyperliquid.base_url()
      assert is_binary(url)
      assert String.contains?(url, "hyperliquid")
    end

    test "info_url includes /info endpoint" do
      assert String.ends_with?(Hyperliquid.info_url(), "/info")
    end

    test "exchange_url includes /exchange endpoint" do
      assert String.ends_with?(Hyperliquid.exchange_url(), "/exchange")
    end

    test "headers returns content-type and accept headers" do
      headers = Hyperliquid.headers()
      assert is_list(headers)
      assert {"content-type", "application/json"} in headers
      assert {"accept", "application/json"} in headers
    end
  end

  describe "info_request/2" do
    test "successfully makes meta info request" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["type"] == "meta"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "universe" => [
            %{"name" => "ETH", "szDecimals" => 4, "maxLeverage" => 50}
          ]
        }))
      end)

      assert {:ok, result} = Hyperliquid.info_request("meta")
      assert is_map(result)
      assert Map.has_key?(result, "universe")
    end

    test "successfully makes clearinghouseState request with user parameter" do
      test_address = "0x0403369c02199a0cb827f4d6492927e9fa5668d5"

      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["type"] == "clearinghouseState"
        assert decoded["user"] == test_address

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "assetPositions" => [],
          "crossMarginSummary" => %{
            "accountValue" => "10000.0",
            "totalMarginUsed" => "0.0",
            "totalNtlPos" => "0.0",
            "totalRawUsd" => "10000.0"
          }
        }))
      end)

      assert {:ok, result} = Hyperliquid.info_request("clearinghouseState", %{"user" => test_address})
      assert Map.has_key?(result, "crossMarginSummary")
    end

    test "handles API error response" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{"error" => "Bad request"}))
      end)

      assert {:error, %{status: 400, body: _}} = Hyperliquid.info_request("invalidType")
    end
  end

  describe "private_key/0" do
    test "returns error when not configured" do
      original = Application.get_env(:lux, :accounts)
      Application.put_env(:lux, :accounts, [])
      assert {:error, :missing_private_key} = Hyperliquid.private_key()
      if original, do: Application.put_env(:lux, :accounts, original)
    end
  end

  describe "account_address/0" do
    test "returns empty string when not configured" do
      original = Application.get_env(:lux, :accounts)
      Application.put_env(:lux, :accounts, [])
      assert Hyperliquid.account_address() == ""
      if original, do: Application.put_env(:lux, :accounts, original)
    end
  end
end
