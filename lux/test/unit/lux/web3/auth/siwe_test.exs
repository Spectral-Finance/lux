defmodule Lux.Web3.Auth.SIWETest do
  use UnitAPICase, async: true

  alias Lux.Web3.Auth.SIWE

  @address "0xAbCdEfAbCdEfAbCdEfAbCdEfAbCdEfAbCdEfAbCd"
  @issued_at "2026-05-13T02:00:00Z"
  @now ~U[2026-05-13 02:10:00Z]

  describe "build_message/1 and parse_message/1" do
    test "round-trips core EIP-4361 fields" do
      message =
        SIWE.build_message(%{
          domain: "example.com",
          address: @address,
          statement: "Sign in to Lux",
          uri: "https://example.com/login",
          chain_id: 1,
          nonce: "AbC12345",
          issued_at: @issued_at,
          expiration_time: "2026-05-13T03:00:00Z",
          resources: ["https://example.com/terms"]
        })

      assert {:ok, parsed} = SIWE.parse_message(message)
      assert parsed.domain == "example.com"
      assert parsed.address == @address
      assert parsed.uri == "https://example.com/login"
      assert parsed.chain_id == 1
      assert parsed.nonce == "AbC12345"
      assert parsed.resources == ["https://example.com/terms"]
    end
  end

  describe "validate_message/2" do
    test "accepts valid constraints" do
      message = %{
        domain: "example.com",
        address: @address,
        chain_id: 1,
        nonce: "AbC12345",
        expiration_time: "2026-05-13T03:00:00Z"
      }

      assert SIWE.validate_message(message, %{domain: "example.com", chain_id: 1, now: @now}) == :ok
    end

    test "rejects replay-prone nonce and expired messages" do
      assert SIWE.validate_message(
               %{
                 domain: "example.com",
                 address: @address,
                 chain_id: 1,
                 nonce: "short",
                 expiration_time: "2026-05-13T03:00:00Z"
               },
               %{now: @now}
             ) == {:error, :invalid_nonce}

      assert SIWE.validate_message(
               %{
                 domain: "example.com",
                 address: @address,
                 chain_id: 1,
                 nonce: "AbC12345",
                 expiration_time: "2026-05-13T01:00:00Z"
               },
               %{now: @now}
             ) == {:error, :expired}
    end
  end

  describe "verify_signature/3" do
    test "delegates to an injected signature verifier" do
      verifier = fn message, signature, _opts ->
        assert message == "message"
        assert signature == "0xsig"
        {:ok, String.downcase(@address)}
      end

      assert SIWE.verify_signature("message", "0xsig", %{verifier: verifier}) ==
               {:ok, String.downcase(@address)}
    end

    test "requires an explicit verifier" do
      assert SIWE.verify_signature("message", "0xsig") == {:error, :signature_verifier_not_configured}
    end
  end
end
