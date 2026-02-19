defmodule Lux.Web3.Auth.RBACTest do
  @moduledoc """
  Tests for the RBAC module covering role definition, assignment,
  permission checking, and role hierarchy.
  """

  use UnitCase

  alias Lux.Web3.Auth.RBAC

  @test_address "0x71C7656EC7ab88b098defB751B7401B5f6d8976F"

  setup do
    roles_table = :"rbac_roles_#{:erlang.unique_integer([:positive])}"
    assignments_table = :"rbac_assignments_#{:erlang.unique_integer([:positive])}"
    name = :"rbac_server_#{:erlang.unique_integer([:positive])}"

    {:ok, pid} =
      RBAC.start_link(
        name: name,
        roles_table: roles_table,
        assignments_table: assignments_table
      )

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    %{server: name}
  end

  describe "default roles" do
    test "installs admin role", %{server: server} do
      assert {:ok, admin} = RBAC.get_role(:admin, server)
      assert "*:*" in admin.permissions
    end

    test "installs operator role", %{server: server} do
      assert {:ok, operator} = RBAC.get_role(:operator, server)
      assert "agents:read" in operator.permissions
      assert "agents:write" in operator.permissions
      assert "agents:execute" in operator.permissions
    end

    test "installs viewer role", %{server: server} do
      assert {:ok, viewer} = RBAC.get_role(:viewer, server)
      assert "agents:read" in viewer.permissions
      refute "agents:write" in viewer.permissions
    end
  end

  describe "define_role/3" do
    test "creates a custom role", %{server: server} do
      assert :ok =
               RBAC.define_role(
                 :custom_role,
                 %{permissions: ["data:read", "data:write"], description: "Custom"},
                 server
               )

      assert {:ok, role} = RBAC.get_role(:custom_role, server)
      assert "data:read" in role.permissions
      assert "data:write" in role.permissions
    end

    test "overwrites an existing role", %{server: server} do
      RBAC.define_role(:temp, %{permissions: ["a:b"]}, server)
      RBAC.define_role(:temp, %{permissions: ["c:d"]}, server)

      {:ok, role} = RBAC.get_role(:temp, server)
      assert role.permissions == ["c:d"]
    end

    test "supports parent role", %{server: server} do
      RBAC.define_role(
        :manager,
        %{permissions: ["teams:manage"], parent: :operator},
        server
      )

      {:ok, role} = RBAC.get_role(:manager, server)
      assert role.parent == :operator
    end
  end

  describe "delete_role/2" do
    test "removes a role", %{server: server} do
      RBAC.define_role(:deleteme, %{permissions: ["x:y"]}, server)
      assert {:ok, _} = RBAC.get_role(:deleteme, server)

      :ok = RBAC.delete_role(:deleteme, server)
      assert {:error, :not_found} = RBAC.get_role(:deleteme, server)
    end

    test "removes role assignments when role is deleted", %{server: server} do
      RBAC.define_role(:temp_role, %{permissions: ["a:b"]}, server)
      RBAC.assign_role(@test_address, :temp_role, server)

      assert :temp_role in RBAC.get_roles(@test_address, server)

      RBAC.delete_role(:temp_role, server)

      refute :temp_role in RBAC.get_roles(@test_address, server)
    end
  end

  describe "list_roles/1" do
    test "lists all defined roles", %{server: server} do
      roles = RBAC.list_roles(server)
      role_names = Enum.map(roles, fn {name, _} -> name end)

      assert :admin in role_names
      assert :operator in role_names
      assert :viewer in role_names
    end
  end

  describe "assign_role/3" do
    test "assigns a role to an address", %{server: server} do
      assert :ok = RBAC.assign_role(@test_address, :admin, server)
      assert :admin in RBAC.get_roles(@test_address, server)
    end

    test "prevents duplicate assignments", %{server: server} do
      RBAC.assign_role(@test_address, :admin, server)
      RBAC.assign_role(@test_address, :admin, server)

      roles = RBAC.get_roles(@test_address, server)
      assert Enum.count(roles, &(&1 == :admin)) == 1
    end

    test "allows multiple roles", %{server: server} do
      RBAC.assign_role(@test_address, :admin, server)
      RBAC.assign_role(@test_address, :operator, server)

      roles = RBAC.get_roles(@test_address, server)
      assert :admin in roles
      assert :operator in roles
    end

    test "returns error for non-existent role", %{server: server} do
      assert {:error, _} =
               RBAC.assign_role(@test_address, :nonexistent, server)
    end

    test "is case-insensitive for addresses", %{server: server} do
      RBAC.assign_role(String.upcase(@test_address), :admin, server)
      assert :admin in RBAC.get_roles(String.downcase(@test_address), server)
    end
  end

  describe "revoke_role/3" do
    test "removes a role from an address", %{server: server} do
      RBAC.assign_role(@test_address, :admin, server)
      assert :admin in RBAC.get_roles(@test_address, server)

      RBAC.revoke_role(@test_address, :admin, server)
      refute :admin in RBAC.get_roles(@test_address, server)
    end

    test "keeps other roles intact", %{server: server} do
      RBAC.assign_role(@test_address, :admin, server)
      RBAC.assign_role(@test_address, :operator, server)

      RBAC.revoke_role(@test_address, :admin, server)

      refute :admin in RBAC.get_roles(@test_address, server)
      assert :operator in RBAC.get_roles(@test_address, server)
    end
  end

  describe "has_permission?/3" do
    test "admin has all permissions via wildcard", %{server: server} do
      RBAC.assign_role(@test_address, :admin, server)

      assert RBAC.has_permission?(@test_address, "agents:read", server)
      assert RBAC.has_permission?(@test_address, "anything:everything", server)
      assert RBAC.has_permission?(@test_address, "custom:action", server)
    end

    test "operator has specific permissions", %{server: server} do
      RBAC.assign_role(@test_address, :operator, server)

      assert RBAC.has_permission?(@test_address, "agents:read", server)
      assert RBAC.has_permission?(@test_address, "agents:write", server)
      assert RBAC.has_permission?(@test_address, "beams:execute", server)
      refute RBAC.has_permission?(@test_address, "admin:manage", server)
    end

    test "viewer has read-only permissions", %{server: server} do
      RBAC.assign_role(@test_address, :viewer, server)

      assert RBAC.has_permission?(@test_address, "agents:read", server)
      refute RBAC.has_permission?(@test_address, "agents:write", server)
      refute RBAC.has_permission?(@test_address, "agents:execute", server)
    end

    test "returns false for user with no roles", %{server: server} do
      refute RBAC.has_permission?(@test_address, "agents:read", server)
    end

    test "wildcard resource permission", %{server: server} do
      RBAC.define_role(:reader, %{permissions: ["*:read"]}, server)
      RBAC.assign_role(@test_address, :reader, server)

      assert RBAC.has_permission?(@test_address, "agents:read", server)
      assert RBAC.has_permission?(@test_address, "beams:read", server)
      refute RBAC.has_permission?(@test_address, "agents:write", server)
    end

    test "wildcard action permission", %{server: server} do
      RBAC.define_role(:agent_master, %{permissions: ["agents:*"]}, server)
      RBAC.assign_role(@test_address, :agent_master, server)

      assert RBAC.has_permission?(@test_address, "agents:read", server)
      assert RBAC.has_permission?(@test_address, "agents:write", server)
      assert RBAC.has_permission?(@test_address, "agents:delete", server)
      refute RBAC.has_permission?(@test_address, "beams:read", server)
    end

    test "inherits permissions from parent role", %{server: server} do
      RBAC.define_role(
        :manager,
        %{permissions: ["teams:manage"], parent: :viewer},
        server
      )

      RBAC.assign_role(@test_address, :manager, server)

      # Own permission
      assert RBAC.has_permission?(@test_address, "teams:manage", server)
      # Inherited from viewer
      assert RBAC.has_permission?(@test_address, "agents:read", server)
      # Not in viewer
      refute RBAC.has_permission?(@test_address, "agents:write", server)
    end

    test "handles multi-level inheritance", %{server: server} do
      RBAC.define_role(:level1, %{permissions: ["l1:action"]}, server)
      RBAC.define_role(:level2, %{permissions: ["l2:action"], parent: :level1}, server)
      RBAC.define_role(:level3, %{permissions: ["l3:action"], parent: :level2}, server)

      RBAC.assign_role(@test_address, :level3, server)

      assert RBAC.has_permission?(@test_address, "l3:action", server)
      assert RBAC.has_permission?(@test_address, "l2:action", server)
      assert RBAC.has_permission?(@test_address, "l1:action", server)
    end
  end

  describe "get_permissions/2" do
    test "returns all effective permissions", %{server: server} do
      RBAC.assign_role(@test_address, :viewer, server)

      perms = RBAC.get_permissions(@test_address, server)
      assert "agents:read" in perms
      assert "beams:read" in perms
    end

    test "includes inherited permissions", %{server: server} do
      RBAC.define_role(
        :extended_viewer,
        %{permissions: ["custom:read"], parent: :viewer},
        server
      )

      RBAC.assign_role(@test_address, :extended_viewer, server)

      perms = RBAC.get_permissions(@test_address, server)
      assert "custom:read" in perms
      assert "agents:read" in perms
    end

    test "returns empty list for user with no roles", %{server: server} do
      assert [] = RBAC.get_permissions(@test_address, server)
    end
  end
end
