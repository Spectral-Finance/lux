defmodule Lux.Web3.AuthFrameworkTest do
  use ExUnit.Case, async: false

  alias Lux.Prisms.Web3.AuthPrism
  alias Lux.Web3.Auth
  alias Lux.Web3.Auth.AuditLog
  alias Lux.Web3.Auth.RBAC
  alias Lux.Web3.Auth.Signature
  alias Lux.Web3.Auth.SIWE
  alias Lux.Web3.Auth.TokenGate

  @priv_key_1 "0x4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f362318"
  @priv_key_2 "0x5c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f362319"

  setup do
    Auth.reset!()
    {:ok, addr1} = Signature.address_from_private_key(@priv_key_1)
    {:ok, addr2} = Signature.address_from_private_key(@priv_key_2)
    {:ok, addr1: addr1, addr2: addr2}
  end

  describe "SIWE (EIP-4361) message construction, parsing, and validation" do
    test "builds, formats, and round-trip parses a full SIWE message", %{addr1: addr1} do
      params = %{
        domain: "lux.spectral.finance",
        address: addr1,
        statement: "Sign in to Lux Agent Platform.",
        uri: "https://lux.spectral.finance/login",
        version: "1",
        chain_id: 1,
        nonce: "abcd1234efgh5678",
        issued_at: "2025-02-01T10:00:00Z",
        expiration_time: "2025-02-01T11:00:00Z",
        not_before: "2025-02-01T09:55:00Z",
        request_id: "req-99",
        resources: ["https://lux.spectral.finance/api/v1"]
      }

      assert {:ok, siwe} = SIWE.build(params)
      raw = SIWE.format(siwe)
      assert {:ok, parsed} = SIWE.parse(raw)

      assert parsed.domain == "lux.spectral.finance"
      assert parsed.address == addr1
      assert parsed.statement == "Sign in to Lux Agent Platform."
      assert parsed.chain_id == 1
      assert parsed.nonce == "abcd1234efgh5678"
      assert parsed.request_id == "req-99"
      assert parsed.resources == ["https://lux.spectral.finance/api/v1"]
    end

    test "validates expiration, domain, and nonce constraints", %{addr1: addr1} do
      {:ok, siwe} =
        SIWE.build(%{
          domain: "lux.spectral.finance",
          address: addr1,
          uri: "https://lux.spectral.finance",
          chain_id: 1,
          nonce: "validnonce12345",
          issued_at: "2025-02-01T10:00:00Z",
          expiration_time: "2025-02-01T11:00:00Z"
        })

      {:ok, valid_now, _} = DateTime.from_iso8601("2025-02-01T10:30:00Z")
      {:ok, expired_now, _} = DateTime.from_iso8601("2025-02-01T12:00:00Z")

      assert :ok == SIWE.validate(siwe, now: valid_now, domain: "lux.spectral.finance")
      assert {:error, :message_expired} == SIWE.validate(siwe, now: expired_now)
      assert {:error, :domain_mismatch} == SIWE.validate(siwe, domain: "other.io")
      assert {:error, :nonce_mismatch} == SIWE.validate(siwe, nonce: "wrongnonce")
    end
  end

  describe "Cryptographic Signature (EIP-191 and M-of-N Multisig)" do
    test "signs and recovers single-key and M-of-N multisig proofs", %{
      addr1: addr1,
      addr2: addr2
    } do
      msg = "Authorize Lux Agent Deployment"
      assert {:ok, sig1} = Signature.sign_message(msg, @priv_key_1)
      assert {:ok, sig2} = Signature.sign_message(msg, @priv_key_2)

      assert Signature.verify_signature(msg, sig1, addr1)
      refute Signature.verify_signature(msg, sig1, addr2)

      assert {:ok, signers} =
               Signature.verify_multisig(msg, [sig1, sig2], [addr1, addr2], 2)

      assert length(signers) == 2

      assert {:error, :insufficient_multisig_signatures} =
               Signature.verify_multisig(msg, [sig1], [addr1, addr2], 2)
    end
  end

  describe "Role-Based Access Control (RBAC)" do
    test "assigns roles and checks permissions", %{addr1: addr1} do
      assert :ok = RBAC.assign_role(addr1, :trader)
      assert RBAC.has_permission?(addr1, :execute_trades)
      assert RBAC.has_permission?(addr1, :read_analytics)
      refute RBAC.has_permission?(addr1, :manage_roles)

      assert :ok = RBAC.assign_role(addr1, :admin)
      assert RBAC.has_permission?(addr1, :manage_roles)
    end
  end

  describe "Token-Gated Access Control" do
    test "evaluates ERC-20 balance requirement via Req plug", %{addr1: addr1} do
      plug = fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => "0x3e8"})
      end

      rule = %{
        type: :erc20,
        contract_address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        min_balance: 500
      }

      assert {:ok, %{granted: true, balance: 1_000}} =
               TokenGate.check_access(addr1, rule, req_options: [plug: plug])
    end
  end

  describe "Unified Auth and AuthPrism end-to-end" do
    test "creates SIWE challenge, authenticates session, and enforces RBAC", %{addr1: addr1} do
      assert {:ok, challenge} =
               Auth.create_challenge(%{
                 domain: "lux.spectral.finance",
                 address: addr1,
                 uri: "https://lux.spectral.finance/auth"
               })

      {:ok, sig} = Signature.sign_message(challenge.message, @priv_key_1)
      assert {:ok, session} = Auth.authenticate_siwe(challenge.message, sig)
      assert session.address == String.downcase(addr1)

      # Replay protection rejects reusing the same SIWE message/nonce
      assert {:error, :nonce_already_used} = Auth.authenticate_siwe(challenge.message, sig)

      assert :ok = RBAC.assign_role(addr1, :trader)
      assert {:ok, verified} = Auth.verify_session(session.token)
      assert :trader in verified.roles

      assert {:ok, %{authorized: true}} = Auth.authorize(addr1, :execute_trades)

      assert {:ok, %{status: "ok", data: %{entries: entries}}} =
               AuthPrism.handler(%{action: "audit_entries"}, %{})

      assert length(entries) >= 3
      assert is_list(AuditLog.list_entries(address: addr1))
    end
  end
end
