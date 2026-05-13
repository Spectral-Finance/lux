defmodule Lux.Web3.Auth.RBACTest do
  use UnitCase, async: true

  alias Lux.Web3.Auth.RBAC

  @address "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf"

  test "grants roles and checks permissions" do
    policy =
      RBAC.new()
      |> RBAC.put_role(:admin, [:all])
      |> RBAC.put_role(:viewer, [%{action: :read, resource: :dashboard}])
      |> RBAC.grant_role(@address, :viewer)

    assert RBAC.roles_for(policy, String.downcase(@address)) == [:viewer]
    assert RBAC.authorized?(policy, @address, :read, :dashboard)
    refute RBAC.authorized?(policy, @address, :write, :dashboard)

    admin_policy = RBAC.grant_role(policy, @address, :admin)
    assert RBAC.authorized?(admin_policy, %{roles: [:admin]}, :delete, :anything)
  end

  test "revokes roles" do
    policy =
      RBAC.new()
      |> RBAC.put_role(:viewer, [%{action: :read, resource: :dashboard}])
      |> RBAC.grant_role(@address, :viewer)
      |> RBAC.revoke_role(@address, :viewer)

    refute RBAC.authorized?(policy, @address, :read, :dashboard)
  end
end
