defmodule Lux.Prisms.Discord.MessageManagementTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Discord.MessageManagement

  setup do
    Req.Test.stub(Lux.Integrations.Discord.Client, fn conn ->
      case {conn.method, conn.request_path} do
        {"POST", "/api/v10/channels/" <> _} ->
          Req.Test.json(conn, %{"id" => "msg_123", "content" => "hello"})
        {"PATCH", "/api/v10/channels/" <> _} ->
          Req.Test.json(conn, %{"id" => "msg_123", "content" => "edited"})
        {"DELETE", "/api/v10/channels/" <> _} ->
          Req.Test.json(conn, %{})
        {"GET", "/api/v10/channels/" <> _} ->
          Req.Test.json(conn, [%{"id" => "msg_1"}, %{"id" => "msg_2"}])
        {"PUT", "/api/v10/channels/" <> _} ->
          Req.Test.json(conn, %{})
      end
    end)
    :ok
  end

  @opts %{plug: {Req.Test, Lux.Integrations.Discord.Client}}

  test "send message" do
    {:ok, body} = MessageManagement.send_message("ch1", %{content: "hello"}, @opts)
    assert body["id"] == "msg_123"
  end

  test "edit message" do
    {:ok, body} = MessageManagement.edit_message("ch1", "msg_123", %{content: "edited"}, @opts)
    assert body["content"] == "edited"
  end

  test "delete message" do
    {:ok, _} = MessageManagement.delete_message("ch1", "msg_123", @opts)
  end

  test "get history" do
    {:ok, body} = MessageManagement.get_history("ch1", %{limit: 10}, @opts)
    assert length(body) == 2
  end

  test "pin message" do
    {:ok, _} = MessageManagement.pin_message("ch1", "msg_123", @opts)
  end

  test "add reaction" do
    {:ok, _} = MessageManagement.add_reaction("ch1", "msg_123", "👍", @opts)
  end

  test "bulk delete" do
    {:ok, _} = MessageManagement.bulk_delete("ch1", ["m1", "m2"], @opts)
  end

  test "send with reply_to" do
    {:ok, body} = MessageManagement.send_message("ch1", %{content: "reply", reply_to: "orig"}, @opts)
    assert body["id"]
  end
end
