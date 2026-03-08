defmodule Lux.Prisms.Discord.AgentDiscordTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Discord.{ServerManagement, ConversationManager, MemberInteraction}

  defp mock_plug(status, body) do
    {Req.Test, __MODULE__.Stub}
    |> tap(fn _ ->
      Req.Test.stub(__MODULE__.Stub, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(status, Jason.encode!(body))
      end)
    end)
  end

  defp opts(status \\ 200, body \\ %{}) do
    plug = mock_plug(status, body)
    %{token: "test_token", plug: plug}
  end

  # === ServerManagement ===

  test "join_server success" do
    {:ok, body} = ServerManagement.join_server("abc123", opts(200, %{"guild" => %{"id" => "1"}}))
    assert body["guild"]["id"] == "1"
  end

  test "join_server invalid invite" do
    assert {:error, {404, "Unknown Invite"}} = ServerManagement.join_server("bad", opts(404, %{"message" => "Unknown Invite"}))
  end

  test "leave_server success" do
    {:ok, _} = ServerManagement.leave_server("guild1", opts(204, %{}))
  end

  test "create_channel success" do
    {:ok, body} = ServerManagement.create_channel("guild1", %{name: "general", type: 0}, opts(200, %{"id" => "ch1", "name" => "general"}))
    assert body["name"] == "general"
  end

  test "delete_channel success" do
    {:ok, _} = ServerManagement.delete_channel("ch1", opts(200, %{"id" => "ch1"}))
  end

  test "create_role success" do
    {:ok, body} = ServerManagement.create_role("guild1", %{name: "Admin", color: 0xFF0000}, opts(200, %{"id" => "r1", "name" => "Admin"}))
    assert body["name"] == "Admin"
  end

  test "assign_role success" do
    {:ok, _} = ServerManagement.assign_role("g1", "u1", "r1", opts(204, %{}))
  end

  test "remove_role success" do
    {:ok, _} = ServerManagement.remove_role("g1", "u1", "r1", opts(204, %{}))
  end

  test "list_members success" do
    members = [%{"user" => %{"id" => "1"}}, %{"user" => %{"id" => "2"}}]
    {:ok, body} = ServerManagement.list_members("g1", opts(200, members))
    assert length(body) == 2
  end

  test "server management unauthorized" do
    assert {:error, :invalid_token} = ServerManagement.create_channel("g1", %{name: "x"}, opts(401, %{}))
  end

  # === ConversationManager ===

  test "create_thread success" do
    {:ok, body} = ConversationManager.create_thread("ch1", %{name: "Discussion"}, opts(200, %{"id" => "t1", "name" => "Discussion"}))
    assert body["name"] == "Discussion"
  end

  test "send_message success" do
    {:ok, body} = ConversationManager.send_message("ch1", "Hello!", opts(200, %{"id" => "m1", "content" => "Hello!"}))
    assert body["content"] == "Hello!"
  end

  test "edit_message success" do
    {:ok, body} = ConversationManager.edit_message("ch1", "m1", "Updated", opts(200, %{"id" => "m1", "content" => "Updated"}))
    assert body["content"] == "Updated"
  end

  test "delete_message success" do
    {:ok, _} = ConversationManager.delete_message("ch1", "m1", opts(204, %{}))
  end

  test "add_reaction success" do
    {:ok, _} = ConversationManager.add_reaction("ch1", "m1", "👍", opts(204, %{}))
  end

  test "get_history success" do
    messages = [%{"id" => "1", "content" => "hi"}, %{"id" => "2", "content" => "bye"}]
    {:ok, body} = ConversationManager.get_history("ch1", opts(200, messages))
    assert length(body) == 2
  end

  test "analyze_history" do
    messages = [
      %{"author" => %{"id" => "u1"}, "content" => "hi"},
      %{"author" => %{"id" => "u1"}, "content" => "there"},
      %{"author" => %{"id" => "u2"}, "content" => "hey"}
    ]
    {:ok, analysis} = ConversationManager.analyze_history(messages)
    assert analysis.total_messages == 3
    assert analysis.unique_authors == 2
    assert analysis.author_counts["u1"] == 2
  end

  test "analyze_history empty" do
    {:ok, analysis} = ConversationManager.analyze_history([])
    assert analysis.total_messages == 0
    assert analysis.unique_authors == 0
  end

  test "send_message unauthorized" do
    assert {:error, :invalid_token} = ConversationManager.send_message("ch1", "x", opts(401, %{}))
  end

  # === MemberInteraction ===

  test "kick_member success" do
    {:ok, _} = MemberInteraction.kick_member("g1", "u1", opts(204, %{}))
  end

  test "ban_member success" do
    {:ok, _} = MemberInteraction.ban_member("g1", "u1", opts(204, %{}))
  end

  test "unban_member success" do
    {:ok, _} = MemberInteraction.unban_member("g1", "u1", opts(204, %{}))
  end

  test "get_member success" do
    {:ok, body} = MemberInteraction.get_member("g1", "u1", opts(200, %{"user" => %{"id" => "u1", "username" => "test"}}))
    assert body["user"]["username"] == "test"
  end

  test "nickname success" do
    {:ok, _} = MemberInteraction.nickname("g1", "u1", "NewNick", opts(200, %{"nick" => "NewNick"}))
  end

  test "get_member not found" do
    assert {:error, {404, "Unknown Member"}} = MemberInteraction.get_member("g1", "bad", opts(404, %{"message" => "Unknown Member"}))
  end

  test "ban_member forbidden" do
    assert {:error, {403, "Missing Permissions"}} = MemberInteraction.ban_member("g1", "u1", opts(403, %{"message" => "Missing Permissions"}))
  end

  # === Cross-module ===

  test "all modules have expected exports" do
    assert function_exported?(ServerManagement, :join_server, 2)
    assert function_exported?(ServerManagement, :create_channel, 3)
    assert function_exported?(ServerManagement, :create_role, 3)
    assert function_exported?(ConversationManager, :create_thread, 3)
    assert function_exported?(ConversationManager, :send_message, 3)
    assert function_exported?(ConversationManager, :analyze_history, 1)
    assert function_exported?(MemberInteraction, :send_dm, 3)
    assert function_exported?(MemberInteraction, :kick_member, 3)
    assert function_exported?(MemberInteraction, :ban_member, 3)
  end
end
