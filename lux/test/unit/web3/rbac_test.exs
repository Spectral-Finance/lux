defmodule Lux.Web3.RBACTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Schemas.RolePermission

  describe "new/0" do
    test "creates an empty RBAC schema" do
      schema = RolePermission.new()
      assert %RolePermission{} = schema
      assert schema.roles == %{}
      assert schema.address_roles == %{}
    end
  end

  describe "add_role/2" do
    test "adds a role with permissions" do
      role = %{
        name: :trader,
        description: "Can execute trades",
        permissions: [
          %{required: :trader, resource: "*", action: "execute_trade"}
        ]
      }

      schema = RolePermission.new() |> RolePermission.add_role(role)
      assert "trader" in Map.keys(schema.roles)
      assert schema.roles["trader"].description == "Can execute trades"
    end
  end

  describe "assign_role/3 and revoke_role/3" do
    test "assigns and revokes roles correctly" do
      role = %{name: :admin, description: "Admin role", permissions: []}
      schema = RolePermission.new() |> RolePermission.add_role(role)

      schema = RolePermission.assign_role(schema, "0xabc", "admin")
      assert ["admin"] = RolePermission.get_roles(schema, "0xabc")

      schema = RolePermission.revoke_role(schema, "0xabc", "admin")
      assert [] = RolePermission.get_roles(schema, "0xabc")
    end

    test "addresses are case-insensitive" do
      role = %{name: :user, description: "User", permissions: []}
      schema = RolePermission.new() |> RolePermission.add_role(role)

      RolePermission.assign_role(schema, "0xABCD", "user")
      assert ["user"] = RolePermission.get_roles(schema, "0xabcd")
    end
  end

  describe "has_permission?/3" do
    test "checks permissions correctly" do
      role = %{
        name: :viewer,
        description: "Read-only access",
        permissions: [
          %{required: :viewer, resource: "reports", action: "read"}
        ]
      }

      schema = RolePermission.new() |> RolePermission.add_role(role)
      schema = RolePermission.assign_role(schema, "0x111", "viewer")

      perm = %{required: :viewer, resource: "reports", action: "read"}
      assert RolePermission.has_permission?(schema, "0x111", perm)

      wrong_perm = %{required: :viewer, resource: "reports", action: "write"}
      refute RolePermission.has_permission?(schema, "0x111", wrong_perm)
    end
  end

  describe "multisig_config" do
    test "sets and checks multisig configuration" do
      config = %{
        required: :multisig,
        signers: ["0xA", "0xB", "0xC"],
        threshold: 2
      }

      schema = RolePermission.new() |> RolePermission.set_multisig_config(config)
      assert RolePermission.get_multisig_config(schema) == config
      assert RolePermission.is_multisig_signer?(schema, "0xa")
      refute RolePermission.is_multisig_signer?(schema, "0xD")
    end
  end
end
