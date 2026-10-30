defmodule Lux.Web3.AuthTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Auth
  alias Lux.Web3.Auth.Session

  @test_addr "0x1234567890123456789012345678901234567890"

  describe "SIWE formatting and parsing" do
    test "formats and parses EIP-4361 compliant messages" do
      params = %{
        domain: "app.lux.network",
        address: @test_addr,
        uri: "https://app.lux.network",
        chain_id: 1,
        nonce: "test_nonce_987",
        issued_at: "2026-10-30T00:00:00Z"
      }

      msg = Auth.format_siwe_message(params)

      assert String.contains?(msg, "app.lux.network wants you to sign in")
      assert String.contains?(msg, @test_addr)
      assert String.contains?(msg, "Nonce: test_nonce_987")

      assert {:ok, parsed} = Auth.parse_siwe_message(msg)
      assert parsed.domain == "app.lux.network"
      assert parsed.address == @test_addr
      assert parsed.chain_id == 1
      assert parsed.nonce == "test_nonce_987"
    end
  end

  describe "signature verification" do
    test "accepts valid 65-byte hex signatures" do
      dummy_sig = "0x" <> String.duplicate("ab", 65)
      assert {:ok, res} = Auth.verify_signature(@test_addr, "message", dummy_sig)
      assert res.verified == true
    end

    test "rejects malformed signatures" do
      assert {:error, :invalid_signature_format} =
               Auth.verify_signature(@test_addr, "message", "0xshort")
    end
  end

  describe "session lifecycle & RBAC" do
    test "creates active session with roles and permissions" do
      session = Auth.create_session(@test_addr, roles: [:admin], permissions: [:write, :deploy])

      assert Auth.valid_session?(session)
      assert Auth.has_role?(session, :admin)
      refute Auth.has_role?(session, :superadmin)
      assert Auth.has_permission?(session, :deploy)
      refute Auth.has_permission?(session, :delete)
    end

    test "identifies expired sessions" do
      past = System.system_time(:second) - 100
      expired_session = %Session{address: @test_addr, expires_at: past}

      refute Auth.valid_session?(expired_session)
      refute Auth.has_role?(expired_session, :admin)
    end
  end

  describe "token gating" do
    test "validates token balance criteria" do
      assert :ok = Auth.evaluate_token_gate(100.5, 50.0)
      assert {:error, {:insufficient_balance, 10.0, 50.0}} = Auth.evaluate_token_gate(10.0, 50.0)
    end
  end
end
