defmodule Lux.Web3.Auth.RBAC.Test do
  use ExUnit.Case, async: true
  @moduletag :unit

  alias Lux.Web3.Auth.RBAC

  setup do
    RBAC.init_store()
    :ok
  end

  describe "add_role/1" do
    test "adds a new role" do
      assert :ok = RBAC.add_role(%{name: :moderator, permissions: [:review, :flag]})
      roles = RBAC.list_roles()
      role_names = Enum.map(roles, & &1.name)
      assert "moderator" in role_names
    end
  end

  describe "assign_role/3 and revoke_role/3" do
    test "assigns and revokes a role" do
      addr = "0xrbactest1address1234567890123456789012"
      RBAC.assign_role(addr, :viewer)

      assert RBAC.has_role?(addr, :viewer)
      assert RBAC.has_permission?(addr, :view_dashboard)

      RBAC.revoke_role(addr, :viewer)
      refute RBAC.has_role?(addr, :viewer)
    end
  end

  describe "has_permission?/2" do
    test "checks direct permissions" do
      addr = "0xrbacpermtestaddr1234567890123456789012"
      RBAC.assign_role(addr, :trader)

      assert RBAC.has_permission?(addr, :execute_trades)
      assert RBAC.has_permission?(addr, :view_positions)
    end

    test "inherits permissions from parent roles" do
      addr = "0xrbacinherittestaddr123456789012345678901"
      RBAC.assign_role(addr, :trader)

      assert RBAC.has_permission?(addr, :view_dashboard)
      assert RBAC.has_permission?(addr, :view_markets)
    end

    test "admin has all permissions" do
      addr = "0xrbacadmintestaddr1234567890123456789012"
      RBAC.assign_role(addr, :admin)

      assert RBAC.has_permission?(addr, :all)
      assert RBAC.has_permission?(addr, :execute_trades)
      assert RBAC.has_permission?(addr, :manage_users)
    end

    test "returns false for non-assigned address" do
      refute RBAC.has_permission?("0xunknown1234567890abcdef1234567890abcdef1234", :execute_trades)
    end
  end

  describe "get_permissions/1" do
    test "returns all effective permissions" do
      addr = "0xrbacpermstestaddr1234567890123456789012"
      RBAC.assign_role(addr, :viewer)

      perms = RBAC.get_permissions(addr)
      assert "view_dashboard" in perms
      assert "view_positions" in perms
    end
  end

  describe "get_roles/1" do
    test "returns assigned roles for an address" do
      addr = "0xrbacrolestestaddr1234567890123456789012"
      RBAC.assign_role(addr, :viewer)
      RBAC.assign_role(addr, :trader)

      roles = RBAC.get_roles(addr)
      assert :viewer in roles
      assert :trader in roles
    end

    test "returns empty list for unknown address" do
      assert [] = RBAC.get_roles("0xunknown1234567890abcdef1234567890abcdef1234")
    end
  end

  describe "has_role?/2" do
    test "returns true for directly assigned role" do
      addr = "0xrbacrolestest2addr1234567890123456789012"
      RBAC.assign_role(addr, :manager)

      assert RBAC.has_role?(addr, :manager)
    end

    test "returns false for non-assigned role" do
      addr = "0xrbacrolestest3addr1234567890123456789012"
      RBAC.assign_role(addr, :viewer)

      refute RBAC.has_role?(addr, :admin)
    end
  end

  describe "list_roles/0" do
    test "returns all registered roles" do
      roles = RBAC.list_roles()
      role_names = Enum.map(roles, & &1.name)
      assert "admin" in role_names
      assert "manager" in role_names
      assert "trader" in role_names
      assert "viewer" in role_names
    end
  end

  describe "list_assignments/0" do
    test "returns all role assignments" do
      addr = "0xrbacassignstestaddr123456789012345678901"
      RBAC.assign_role(addr, :viewer)

      assignments = RBAC.list_assignments()
      assert is_list(assignments)
      assert length(assignments) > 0
    end
  end
end
