defmodule Lux.Web3.AuthTest do
  use ExUnit.Case
  alias Lux.Web3.Auth.SIWE
  alias Lux.Web3.Auth.Manager

  describe "EIP-4361 SIWE Engine" do
    test "generates secure nonces" do
      nonce1 = SIWE.generate_nonce()
      nonce2 = SIWE.generate_nonce()
      assert String.length(nonce1) == 32
      assert nonce1 != nonce2
    end

    test "formats standard EIP-4361 message correctly" do
      msg = %SIWE{
        domain: "spectral.finance",
        address: "0x8366bCe3a2D379Dec7656D7A67015789FaF999f20",
        statement: "Sign in to Lux Autonomous Agent Hub",
        uri: "https://spectral.finance",
        version: "1",
        chain_id: 1,
        nonce: "abcdef1234567890",
        issued_at: ~U[2026-09-10 12:00:00Z]
      }

      formatted = SIWE.format_message(msg)
      assert formatted =~ "spectral.finance wants you to sign in"
      assert formatted =~ "0x8366bCe3a2D379Dec7656D7A67015789FaF999f20"
      assert formatted =~ "Nonce: abcdef1234567890"
    end
  end

  describe "RBAC & Token Gating" do
    test "authorizes valid user role" do
      assert {:ok, :authorized} = Manager.authorize("0x8366...", :admin, [:user, :admin])
    end

    test "denies unauthorized user role" do
      assert {:error, :unauthorized} = Manager.authorize("0x8366...", :superadmin, [:user])
    end

    test "validates token-gated access" do
      assert {:ok, :granted} = Manager.check_token_gate(100, 50)
      assert {:error, :insufficient_token_balance} = Manager.check_token_gate(10, 50)
    end
  end
end
