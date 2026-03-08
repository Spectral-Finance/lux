defmodule Lux.Lenses.Telegram.GetGroupMemberCountTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Telegram.GetGroupMemberCount

  setup do
    Req.Test.stub(Lux.Telegram.MemberCountMock, fn conn ->
      Req.Test.json(conn, %{"ok" => true, "result" => 1234})
    end)
    :ok
  end

  test "returns member count" do
    assert {:ok, %{member_count: 1234}} =
      GetGroupMemberCount.focus(%{chat_id: -100123, token: "t", plug: {Req.Test, Lux.Telegram.MemberCountMock}})
  end
end
