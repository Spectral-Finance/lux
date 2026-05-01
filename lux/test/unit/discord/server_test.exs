defmodule Lux.Prisms.Discord.ServerTest do
  use ExUnit.Case, async: true

  describe "JoinServer/1" do
    test "joins a server with valid invite code" do
      params = %{invite_code: "abc123"}
      result = Lux.Prisms.Discord.Server.JoinServer.handler(params, %{name: "TestAgent"})
      assert {:ok, %{joined: true}} = result
    end

    test "returns error with missing invite code" do
      result = Lux.Prisms.Discord.Server.JoinServer.handler(%{}, %{name: "TestAgent"})
      assert {:error, _} = result
    end
  end

  describe "LeaveServer/1" do
    test "leaves a server with valid guild_id" do
      params = %{guild_id: "111111111111111111"}
      result = Lux.Prisms.Discord.Server.LeaveServer.handler(params, %{name: "TestAgent"})
      assert {:ok, %{left: true}} = result
    end

    test "returns error with missing guild_id" do
      result = Lux.Prisms.Discord.Server.LeaveServer.handler(%{}, %{name: "TestAgent"})
      assert {:error, _} = result
    end
  end

  describe "MonitorActivity/1" do
    test "monitors server activity with valid guild_id" do
      params = %{guild_id: "111111111111111111", limit: 10}
      result = Lux.Prisms.Discord.Server.MonitorActivity.handler(params, %{name: "TestAgent"})
      assert {:ok, %{guild_id: "111111111111111111"}} = result
    end
  end
end
