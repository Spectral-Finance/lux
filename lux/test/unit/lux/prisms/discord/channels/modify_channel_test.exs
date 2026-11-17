defmodule Lux.Prisms.Discord.Channels.ModifyChannelTest do
  @moduledoc """
  Test suite for the ModifyChannel module.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Channels.ModifyChannel

  @channel_id "123456789012345678"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully modifies a channel" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["name"] == "new-name"
        assert decoded["topic"] == "New topic"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @channel_id,
          "name" => "new-name",
          "type" => 0
        }))
      end)

      assert {:ok, %{
        modified: true,
        channel_id: @channel_id,
        name: "new-name"
      }} = ModifyChannel.handler(
        %{channel_id: @channel_id, name: "new-name", topic: "New topic"},
        @agent_ctx
      )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, {403, "Missing Permissions"}} = ModifyChannel.handler(
        %{channel_id: @channel_id, name: "new-name"},
        @agent_ctx
      )
    end

    test "validates missing channel_id" do
      assert {:error, "Missing or invalid channel_id"} =
        ModifyChannel.handler(%{name: "test"}, @agent_ctx)
    end
  end
end
