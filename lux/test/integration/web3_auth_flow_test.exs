defmodule Lux.Integration.Web3AuthFlowTest do
  use IntegrationCase, async: true

  alias Lux.Web3.Auth
  alias Lux.Web3.Auth.{RBAC, SIWE, Signature}

  @private_key <<1::256>>
  @address "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf"
  @now ~U[2026-05-13 09:00:00Z]

  @tag :integration
  test "authenticates SIWE, issues session, token gates, and authorizes RBAC action" do
    message =
      SIWE.build_message(%{
        domain: "app.lux.dev",
        address: @address,
        statement: "Sign in to Lux",
        uri: "https://app.lux.dev",
        chain_id: 1,
        nonce: "abc12345",
        issued_at: DateTime.to_iso8601(@now)
      })

    signature = sign(message, @private_key)
    contract = "0x0000000000000000000000000000000000000abc"

    assert {:ok, %{siwe: %{address: @address}, session: session}} =
             Auth.sign_in(message, signature,
               domain: "app.lux.dev",
               chain_id: 1,
               now: @now,
               roles: [:member],
               holdings: %{{1, contract} => 10},
               token_gates: [%{chain_id: 1, contract: contract, min_balance: 1}]
             )

    policy =
      RBAC.new()
      |> RBAC.put_role(:member, [%{action: :read, resource: :workspace}])

    assert :ok = Auth.authorize_session(session, policy, :read, :workspace, now: @now)

    assert {:error, :unauthorized} =
             Auth.authorize_session(session, policy, :write, :workspace, now: @now)
  end

  defp sign(message, private_key) do
    {:ok, {signature, recovery_id}} =
      ExSecp256k1.sign_compact(Signature.personal_hash(message), private_key)

    "0x" <> Base.encode16(signature <> <<recovery_id + 27>>, case: :lower)
  end
end
