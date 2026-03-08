defmodule Lux.Prisms.Telegram.ManageGroupMembersTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Telegram.ManageGroupMembers

  setup do
    Req.Test.stub(Lux.Telegram.GroupMock, fn conn ->
      Req.Test.json(conn, %{"ok" => true, "result" => true})
    end)

    Req.Test.stub(Lux.Telegram.GetMemberMock, fn conn ->
      Req.Test.json(conn, %{"ok" => true, "result" => %{
        "user" => %{"id" => 123, "first_name" => "Alice"},
        "status" => "member"
      }})
    end)
    :ok
  end

  test "ban member" do
    assert {:ok, %{result: true, action: "ban"}} =
      ManageGroupMembers.handler(%{
        action: "ban", chat_id: -100123, user_id: 456,
        token: "test", plug: {Req.Test, Lux.Telegram.GroupMock}
      }, nil)
  end

  test "unban member" do
    assert {:ok, %{result: true, action: "unban"}} =
      ManageGroupMembers.handler(%{
        action: "unban", chat_id: -100123, user_id: 456,
        token: "test", plug: {Req.Test, Lux.Telegram.GroupMock}
      }, nil)
  end

  test "restrict member" do
    assert {:ok, %{result: true, action: "restrict"}} =
      ManageGroupMembers.handler(%{
        action: "restrict", chat_id: -100123, user_id: 456,
        permissions: %{can_send_messages: false},
        token: "test", plug: {Req.Test, Lux.Telegram.GroupMock}
      }, nil)
  end

  test "promote member" do
    assert {:ok, %{result: true, action: "promote"}} =
      ManageGroupMembers.handler(%{
        action: "promote", chat_id: -100123, user_id: 456,
        admin_rights: %{can_delete_messages: true, can_restrict_members: true},
        token: "test", plug: {Req.Test, Lux.Telegram.GroupMock}
      }, nil)
  end

  test "kick member (ban + unban)" do
    assert {:ok, %{result: true, action: "kick"}} =
      ManageGroupMembers.handler(%{
        action: "kick", chat_id: -100123, user_id: 456,
        token: "test", plug: {Req.Test, Lux.Telegram.GroupMock}
      }, nil)
  end

  test "get_member" do
    assert {:ok, %{result: %{"status" => "member"}, action: "get_member"}} =
      ManageGroupMembers.handler(%{
        action: "get_member", chat_id: -100123, user_id: 123,
        token: "test", plug: {Req.Test, Lux.Telegram.GetMemberMock}
      }, nil)
  end
end
