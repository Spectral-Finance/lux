defmodule Lux.Prisms.Discord.MembersTest do
  use ExUnit.Case, async: true

  describe "DirectMessage/1" do
    test "sends a DM with valid params" do
      params = %{user_id: "222222222222222222", content: "Hello from agent!"}
      result = Lux.Prisms.Discord.Members.DirectMessage.handler(params, %{name: "TestAgent"})
      assert {:ok, %{sent: true}} = result
    end

    test "returns error with missing content" do
      params = %{user_id: "222222222222222222"}
      result = Lux.Prisms.Discord.Members.DirectMessage.handler(params, %{name: "TestAgent"})
      assert {:error, _} = result
    end
  end

  describe "KickMember/1" do
    test "kicks a member with valid params" do
      params = %{guild_id: "111111111111111111", user_id: "222222222222222222"}
      result = Lux.Prisms.Discord.Members.KickMember.handler(params, %{name: "TestAgent"})
      assert {:ok, %{kicked: true}} = result
    end
  end

  describe "BanMember/1" do
    test "bans a member with valid params" do
      params = %{guild_id: "111111111111111111", user_id: "222222222222222222"}
      result = Lux.Prisms.Discord.Members.BanMember.handler(params, %{name: "TestAgent"})
      assert {:ok, %{banned: true}} = result
    end
  end

  describe "UserProfile/1" do
    test "gets user profile with valid user_id" do
      params = %{user_id: "222222222222222222"}
      result = Lux.Prisms.Discord.Members.UserProfile.handler(params, %{name: "TestAgent"})
      assert {:ok, %{user_id: "222222222222222222"}} = result
    end

    test "gets guild-specific profile with guild_id" do
      params = %{user_id: "222222222222222222", guild_id: "111111111111111111"}
      result = Lux.Prisms.Discord.Members.UserProfile.handler(params, %{name: "TestAgent"})
      assert {:ok, %{user_id: "222222222222222222"}} = result
    end
  end
end
