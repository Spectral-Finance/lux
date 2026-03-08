defmodule Lux.Web3.Auth.RBACTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Auth.RBAC

  setup do
    name = :"rbac_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = RBAC.start_link(name: name)
    %{pid: pid}
  end

  @addr "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"

  test "define and list roles", %{pid: pid} do
    :ok = RBAC.define_role(pid, :admin, [:read, :write, :delete])
    {:ok, roles} = RBAC.list_roles(pid)
    assert {:admin, perms} = Enum.find(roles, fn {name, _} -> name == :admin end)
    assert :read in perms
  end

  test "assign role to address", %{pid: pid} do
    :ok = RBAC.define_role(pid, :member, [:read])
    :ok = RBAC.assign_role(pid, @addr, :member)
    {:ok, roles} = RBAC.get_roles(pid, @addr)
    assert :member in roles
  end

  test "assign undefined role fails", %{pid: pid} do
    assert {:error, :role_not_found} = RBAC.assign_role(pid, @addr, :phantom)
  end

  test "check permission", %{pid: pid} do
    :ok = RBAC.define_role(pid, :editor, [:read, :write])
    :ok = RBAC.assign_role(pid, @addr, :editor)
    assert RBAC.has_permission?(pid, @addr, :read) == true
    assert RBAC.has_permission?(pid, @addr, :delete) == false
  end

  test "authorize returns ok/error", %{pid: pid} do
    :ok = RBAC.define_role(pid, :viewer, [:read])
    :ok = RBAC.assign_role(pid, @addr, :viewer)
    assert :ok = RBAC.authorize(pid, @addr, :read)
    assert {:error, :unauthorized} = RBAC.authorize(pid, @addr, :write)
  end

  test "revoke role", %{pid: pid} do
    :ok = RBAC.define_role(pid, :mod, [:ban])
    :ok = RBAC.assign_role(pid, @addr, :mod)
    :ok = RBAC.revoke_role(pid, @addr, :mod)
    {:ok, roles} = RBAC.get_roles(pid, @addr)
    assert roles == []
  end

  test "wildcard :all permission", %{pid: pid} do
    :ok = RBAC.define_role(pid, :superadmin, [:all])
    :ok = RBAC.assign_role(pid, @addr, :superadmin)
    assert RBAC.has_permission?(pid, @addr, :anything) == true
  end

  test "address normalization (case insensitive)", %{pid: pid} do
    :ok = RBAC.define_role(pid, :user, [:read])
    :ok = RBAC.assign_role(pid, "0xABCD" <> String.duplicate("0", 36), :user)
    {:ok, roles} = RBAC.get_roles(pid, "0xabcd" <> String.duplicate("0", 36))
    assert :user in roles
  end

  test "token gate management", %{pid: pid} do
    :ok = RBAC.add_token_gate(pid, :holder, "0x" <> String.duplicate("a", 40), 1)
    {:ok, gates} = RBAC.get_token_gates(pid)
    assert length(gates) == 1
    assert hd(gates).role == :holder
  end
end
