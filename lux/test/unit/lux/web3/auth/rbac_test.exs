defmodule Lux.Web3.Auth.RBACTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Auth.RBAC

  @admin_addr "0x1111111111111111111111111111111111111111"
  @user_addr "0x2222222222222222222222222222222222222222"

  describe "permissions_for_role/1" do
    test "super_admin has wildcard :* permission" do
      assert RBAC.permissions_for_role(:super_admin) == [:*]
    end

    test "admin inherits agent, trader, and user permissions" do
      perms = RBAC.permissions_for_role(:admin)
      assert :execute_trades in perms
      assert :call_contracts in perms
      assert :read_data in perms
      assert :administer_users in perms
    end

    test "guest only has read_data" do
      assert RBAC.permissions_for_role(:guest) == [:read_data]
    end
  end

  describe "has_permission?/3" do
    test "checks direct and wildcard permissions" do
      assert RBAC.has_permission?([:super_admin], :any_custom_permission)
      assert RBAC.has_permission?([:trader], :execute_trades)
      refute RBAC.has_permission?([:guest], :execute_trades)
    end

    test "checks permission against address assignments" do
      assignments = %{
        @admin_addr => [:admin],
        @user_addr => [:user]
      }

      assert RBAC.has_permission?(@admin_addr, :administer_users, assignments)
      refute RBAC.has_permission?(@user_addr, :administer_users, assignments)
      assert RBAC.has_permission?(@user_addr, :call_contracts, assignments)
    end
  end

  describe "has_role?/3" do
    test "checks role inheritance hierarchy" do
      assert RBAC.has_role?([:super_admin], :admin)
      assert RBAC.has_role?([:admin], :agent)
      assert RBAC.has_role?([:trader], :user)
      refute RBAC.has_role?([:user], :trader)
    end
  end

  describe "authorize/3" do
    test "returns :ok or {:error, :unauthorized, details}" do
      assert :ok = RBAC.authorize([:trader], :execute_trades)
      assert {:error, :unauthorized, %{required_permission: :administer_users}} =
               RBAC.authorize([:trader], :administer_users)
    end
  end

  describe "assign_role/3 and revoke_role/3" do
    test "updates assignments map dynamically" do
      assignments = %{}
      assignments = RBAC.assign_role(assignments, @user_addr, :trader)
      assert RBAC.has_role?(@user_addr, :trader, assignments)

      assignments = RBAC.revoke_role(assignments, @user_addr, :trader)
      refute RBAC.has_role?(@user_addr, :trader, assignments)
    end
  end
end
