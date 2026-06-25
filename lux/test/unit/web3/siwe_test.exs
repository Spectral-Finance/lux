defmodule Lux.Web3.SIWETest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Auth.SIWE
  alias Lux.Web3.Schemas.SIWEMessage

  describe "challenge/3" do
    test "generates a valid SIWE challenge message" do
      {:ok, msg, message} = SIWE.challenge("0x1234567890abcdef1234567890abcdef12345678", "auth.example.com")

      assert is_struct(msg, SIWEMessage)
      assert msg.domain == "auth.example.com"
      assert msg.address == "0x1234567890abcdef1234567890abcdef12345678"
      assert msg.version == "1"
      assert message =~ "auth.example.com"
      assert message =~ "0x1234567890abcdef1234567890abcdef12345678"
      assert message =~ "I accept the Service Agreement at"
    end

    test "includes optional fields" do
      {:ok, msg, message} =
        SIWE.challenge(
          "0xabcd",
          "example.com",
          statement: "Sign in to Lux",
          ttl_seconds: 7200,
          resources: ["https://api.example.com"]
        )

      assert msg.statement == "Sign in to Lux"
      assert message =~ "Sign in to Lux"
      assert message =~ "RESOURCES"
    end
  end

  describe "build_message/1 and parse_message/1" do
    test "round-trip preserves all fields" do
      msg = %SIWEMessage{
        domain: "test.com",
        address: "0xABCDEF",
        uri: "https://test.com",
        version: "1",
        statement: "Login to test",
        issued_at: "2025-01-01T00:00:00Z",
        expiration_time: "2026-01-01T00:00:00Z",
        not_before: "2024-01-01T00:00:00Z",
        request_id: "req-123",
        resources: ["https://api.test.com"]
      }

      message = SIWEMessage.build_message(msg)
      {:ok, parsed} = SIWEMessage.parse_message(message)

      assert parsed.domain == msg.domain
      assert parsed.address == msg.address
      assert parsed.uri == msg.uri
      assert parsed.version == msg.version
      assert parsed.statement == msg.statement
      assert parsed.request_id == msg.request_id
      assert parsed.resources == msg.resources
    end
  end

  describe "verify_temporal_constraints/1" do
    test "rejects expired messages" do
      msg = %SIWEMessage{
        domain: "test.com",
        address: "0xabc",
        uri: "https://test.com",
        version: "1",
        issued_at: "2020-01-01T00:00:00Z",
        expiration_time: "2020-01-02T00:00:00Z"
      }

      assert {:error, reason} = SIWEMessage.verify_temporal_constraints(msg)
      assert reason =~ "expired"
    end

    test "accepts valid messages" do
      far_future =
        DateTime.utc_now()
        |> DateTime.add(3600, :second)
        |> DateTime.to_iso8601()

      msg = %SIWEMessage{
        domain: "test.com",
        address: "0xabc",
        uri: "https://test.com",
        version: "1",
        issued_at: "2020-01-01T00:00:00Z",
        expiration_time: far_future
      }

      assert {:ok, ^msg} = SIWEMessage.verify_temporal_constraints(msg)
    end
  end
end
