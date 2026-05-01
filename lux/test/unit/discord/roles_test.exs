defmodule Lux.Prisms.Discord.RolesTest do
  use ExUnit.Case, async: true

  describe "AssignRole/1" do
    test "assigns a role with valid params" do
      params = %{guild_id: "111111111111111111", user_id: "222222222222222222", role_id: "333333333333333333"}
      result = Lux.Prisms.Discord.Roles.AssignRole.handler(params, %{name: "TestAgent"})
      assert {:ok, %{assigned: true}} = result
    end

    test "returns error with missing role_id" do
      params = %{guild_id: "111111111111111111", user_id: "222222222222222222"}
      result = Lux.Prisms.Discord.Roles.AssignRole.handler(params, %{name: "TestAgent"})
      assert {:error, _} = result
    end
  end

  describe "RemoveRole/1" do
    test "removes a role with valid params" do
      params = %{guild_id: "111111111111111111", user_id: "222222222222222222", role_id: "333333333333333333"}
      result = Lux.Prisms.Discord.Roles.RemoveRole.handler(params, %{name: "TestAgent"})
      assert {:ok, %{removed: true}} = result
    end
  end

  describe "CreateRole/1" do
    test "creates a role with valid params" do
      params = %{guild_id: "111111111111111111", name: "Moderator", permissions: 8, color: 3447003}
      result = Lux.Prisms.Discord.Roles.CreateRole.handler(params, %{name: "TestAgent"})
      assert {:ok, %{created: true}} = result
    end

    test "returns error with missing name" do
      params = %{guild_id: "111111111111111111"}
      result = Lux.Prisms.Discord.Roles.CreateRole.handler(params, %{name: "TestAgent"})
      assert {:error, _} = result
    end
  end

  describe "ManagePermissions/1" do
    test "manages channel permissions with valid params" do
      params = %{channel_id: "123456789", overwrite_id: "333333333333333333", allow: 1024, deny: 0}
      result = Lux.Prisms.Discord.Roles.ManagePermissions.handler(params, %{name: "TestAgent"})
      assert {:ok, %{updated: true}} = result
    end
  end

  describe "ListRoles/1" do
    test "lists roles for a valid guild" do
      params = %{guild_id: "111111111111111111"}
      result = Lux.Prisms.Discord.Roles.ListRoles.handler(params, %{name: "TestAgent"})
      assert {:ok, %{guild_id: "111111111111111111", roles: _}} = result
    end
  end
end
