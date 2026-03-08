defmodule Lux.Lenses.Telegram.GetGroupAdminsTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Telegram.GetGroupAdmins

  setup do
    Req.Test.stub(Lux.Telegram.AdminsMock, fn conn ->
      Req.Test.json(conn, %{"ok" => true, "result" => [
        %{"user" => %{"id" => 1, "username" => "owner", "first_name" => "Owner"}, "status" => "creator",
          "is_anonymous" => false, "can_manage_chat" => true, "can_delete_messages" => true,
          "can_restrict_members" => true, "can_promote_members" => true, "can_change_info" => true,
          "can_invite_users" => true, "can_pin_messages" => true},
        %{"user" => %{"id" => 2, "username" => "admin1", "first_name" => "Admin"}, "status" => "administrator",
          "can_manage_chat" => true, "can_delete_messages" => true}
      ]})
    end)
    :ok
  end

  test "returns parsed admin list" do
    assert {:ok, %{admins: admins, count: 2}} =
      GetGroupAdmins.focus(%{chat_id: -100123, token: "t", plug: {Req.Test, Lux.Telegram.AdminsMock}})
    assert hd(admins).status == "creator"
    assert hd(admins).can_promote_members == true
  end
end
