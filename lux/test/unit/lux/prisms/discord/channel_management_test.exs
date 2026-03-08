defmodule Lux.Prisms.Discord.ChannelManagementTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Discord.ChannelManagement

  setup do
    Req.Test.stub(Lux.Integrations.Discord.Client, fn conn ->
      case conn.method do
        "POST" -> Req.Test.json(conn, %{"id" => "ch_new", "name" => "test", "type" => 0})
        "PATCH" -> Req.Test.json(conn, %{"id" => "ch_1", "name" => "edited"})
        "DELETE" -> Req.Test.json(conn, %{})
        "GET" -> Req.Test.json(conn, [%{"id" => "ch_1"}, %{"id" => "ch_2"}])
        "PUT" -> Req.Test.json(conn, %{})
      end
    end)
    :ok
  end

  @opts %{plug: {Req.Test, Lux.Integrations.Discord.Client}}

  test "create channel" do
    {:ok, body} = ChannelManagement.create_channel("g1", %{name: "test", type: :text}, @opts)
    assert body["id"] == "ch_new"
  end

  test "edit channel" do
    {:ok, body} = ChannelManagement.edit_channel("ch_1", %{name: "edited"}, @opts)
    assert body["name"] == "edited"
  end

  test "delete channel" do
    {:ok, _} = ChannelManagement.delete_channel("ch_1", @opts)
  end

  test "get channel" do
    {:ok, _} = ChannelManagement.get_channel("ch_1", @opts)
  end

  test "list channels" do
    {:ok, body} = ChannelManagement.list_channels("g1", @opts)
    assert length(body) == 2
  end

  test "set permission" do
    {:ok, _} = ChannelManagement.set_permission("ch_1", "role_1", %{type: 0, allow: 1024, deny: 0}, @opts)
  end

  test "archive channel" do
    {:ok, _} = ChannelManagement.archive_channel("ch_1", @opts)
  end

  test "unarchive channel" do
    {:ok, _} = ChannelManagement.unarchive_channel("ch_1", @opts)
  end
end
