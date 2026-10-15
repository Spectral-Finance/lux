defmodule Lux.Web3.AuthTest do
  use ExUnit.Case, async: false
  alias Lux.Web3.Auth

  setup do
    Auth.init_store()
    :ets.delete_all_objects(:lux_web3_auth_store)
    :ok
  end

  test "EIP-4361 SIWE authentication, nonce replay protection, and session management" do
    nonce = Auth.generate_nonce(300)
    address = "0x3806cd592a508d1992Ed007C2F53de251C2E7452"

    {:ok, msg} =
      Auth.build_siwe_message(%{
        domain: "lux.spectral.finance",
        address: address,
        uri: "https://lux.spectral.finance/login",
        chain_id: 8453,
        nonce: nonce
      })

    {:ok, session} = Auth.authenticate_siwe(msg, "0xvalidsignature123456")
    assert session.address == String.downcase(address)
    assert {:ok, _} = Auth.verify_session(session.token)

    # Replay with same nonce must fail
    assert {:error, :nonce_already_used} = Auth.authenticate_siwe(msg, "0xvalidsignature123456")

    # Revoke session
    :ok = Auth.revoke_session(session.token)
    assert {:error, :session_revoked} = Auth.verify_session(session.token)
  end

  test "multi-signature m-of-n threshold authentication, RBAC, token gating, and audit logs" do
    nonce = Auth.generate_nonce(300)
    multisig_addr = "0x1111111111111111111111111111111111111111"
    signer1 = "0xaaaa000000000000000000000000000000000001"
    signer2 = "0xbbbb000000000000000000000000000000000002"

    {:ok, msg} =
      Auth.build_siwe_message(%{
        domain: "lux.spectral.finance",
        address: multisig_addr,
        uri: "https://lux.spectral.finance",
        chain_id: 1,
        nonce: nonce
      })

    {:ok, _session} =
      Auth.authenticate_siwe(
        msg,
        [{signer1, "0xsig_signer_1_valid"}, {signer2, "0xsig_signer_2_valid"}],
        threshold: 2,
        allowed_signers: [signer1, signer2]
      )

    :ok = Auth.assign_role(multisig_addr, :operator, [:deploy_agent, :execute_trade])
    assert :ok = Auth.authorize(multisig_addr, :deploy_agent)
    assert {:error, :unauthorized} = Auth.authorize(multisig_addr, :emergency_shutdown)

    # Token gating fallback
    assert :ok =
             Auth.authorize(multisig_addr, :emergency_shutdown,
               token_gate: %{token_address: "0xspec", min_balance: 100},
               balance_fetcher: fn _addr, _tok -> {:ok, 250} end
             )

    logs = Auth.list_audit_logs()
    assert length(logs) >= 4
  end
end
