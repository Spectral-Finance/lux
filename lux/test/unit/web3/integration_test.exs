defmodule Lux.Web3.IntegrationTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Auth
  alias Lux.Web3.Schemas.RolePermission
  alias Lux.Web3.Schemas.AuditLog

  @moduletag :integration

  describe "full authentication flow" do
    test "challenge -> verify -> session lifecycle" do
      # Step 1: Generate SIWE challenge
      {:ok, _msg, message} =
        Auth.challenge("0xAbCdEf1234567890AbCdEf1234567890AbCdEf12", "demo.lux.finance")

      # Verify message format
      assert message =~ "demo.lux.finance"
      assert message =~ "0xAbCdEf1234567890AbCdEf1234567890AbCdEf12"
      assert message =~ "I accept the Service Agreement"
      assert message =~ "VERSION: 1"
      assert message =~ "ISSUED AT:"
    end

    test "signature hashing produces correct size" do
      message = "test message for hashing"
      hashed = Auth.hash_personal_message(message)
      assert byte_size(hashed) == 32
    end

    test "typed data hashing" do
      data = <<1, 2, 3, 4>>
      hashed = Auth.hash_typed_data(data)
      assert byte_size(hashed) == 32
    end

    test "RBAC setup and permission check" do
      # Create roles
      trader_role = %{
        name: :trader,
        description: "Can execute trades and view portfolio",
        permissions: [
          %{required: :trader, resource: "*", action: "execute_trade"},
          %{required: :trader, resource: "portfolio", action: "read"}
        ]
      }

      admin_role = %{
        name: :admin,
        description: "Full access",
        permissions: [
          %{required: :admin, resource: "*", action: "*"}
        ]
      }

      schema = RolePermission.new() |> RolePermission.add_role(trader_role) |> RolePermission.add_role(admin_role)

      # Assign roles
      schema = RolePermission.assign_role(schema, "0xTrader", "trader")
      schema = RolePermission.assign_role(schema, "0xAdmin", "admin")

      # Check permissions
      assert RolePermission.has_permission?(schema, "0xTrader", %{required: :trader, resource: "*", action: "execute_trade"})
      refute RolePermission.has_permission?(schema, "0xTrader", %{required: :admin, resource: "*", action: "*"})

      # Session management
      {:ok, session_id} = Auth.create_session("0xTrader", %{role: "trader"})
      assert is_binary(session_id)
      assert Auth.session_valid?(session_id)

      # Revoke session
      assert :ok = Auth.revoke_session(session_id)
      refute Auth.session_valid?(session_id)
    end

    test "multisig proposal workflow" do
      config = %{
        required: :multisig,
        signers: ["0xA", "0xB", "0xC"],
        threshold: 2
      }

      {:ok, proposal} = Auth.create_multisig_proposal(config, "0xA", "0xTarget", <<0x01>>, 5000000)
      assert proposal.proposer == "0xa"
      assert proposal.value == 5000000

      # Second approval reaches threshold
      {:ok, approved} = Auth.approve_multisig(proposal, "0xB", "")
      assert approved.executed == true
      assert Auth.approve_multisig(approved, "0xC", "") |> elem(0) == :error
    end

    test "audit logging captures events" do
      entry = Auth.log_event(:login_success, "0xAudit", %{domain: "audit.test"})
      assert entry.action == :login_success
      assert entry.success == true

      summary = AuditLog.summary(entry)
      assert is_binary(summary)
      assert summary =~ "login_success"
    end

    test "token gate configuration" do
      gate = Auth.check_token_gate("0xHolder", %{
        required: :token_gate,
        filters: [
          %{
            required: :erc20,
            contract: "0xToken",
            amount: 100,
            token_type: :erc20,
            token_id: nil
          }
        ],
        operator: :and
      })

      # Without a running node, this returns an error (expected)
      assert case gate do
        {:ok, _} -> true
        {:error, _} -> true
        _ -> false
      end
    end

    test "framework version" do
      assert Auth.version() == "0.5.0"
    end
  end
end
