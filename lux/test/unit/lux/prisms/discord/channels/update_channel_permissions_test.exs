defmodule Lux.Prisms.Discord.Channels.UpdateChannelPermissionsTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Channels.UpdateChannelPermissions

  @channel_id "123456789012345678"
  @overwrite_id "987654321098765432"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully updates role permission overwrite" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/permissions/#{@overwrite_id}"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["type"] == 0
        assert decoded["allow"] == "2048"
        assert decoded["deny"] == "0"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{updated: true, channel_id: @channel_id, overwrite_id: @overwrite_id}} =
        UpdateChannelPermissions.handler(
          %{
            channel_id: @channel_id,
            overwrite_id: @overwrite_id,
            type: 0,
            allow: "2048",
            deny: "0",
            plug: {Req.Test, DiscordClientMock}
          },
          @agent_ctx
        )
    end

    test "uses default allow/deny of 0 when not provided" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["allow"] == "0"
        assert decoded["deny"] == "0"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{updated: true}} =
        UpdateChannelPermissions.handler(
          %{channel_id: @channel_id, overwrite_id: @overwrite_id, type: 1, plug: {Req.Test, DiscordClientMock}},
          @agent_ctx
        )
    end

    test "handles missing permissions error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      assert {:error, {403, "Missing Permissions"}} =
        UpdateChannelPermissions.handler(
          %{channel_id: @channel_id, overwrite_id: @overwrite_id, type: 0, plug: {Req.Test, DiscordClientMock}},
          @agent_ctx
        )
    end

    test "returns error when type is invalid" do
      assert {:error, "Missing or invalid type (must be 0 for role or 1 for member)"} =
        UpdateChannelPermissions.handler(
          %{channel_id: @channel_id, overwrite_id: @overwrite_id, type: 5},
          @agent_ctx
        )
    end

    test "returns error when channel_id is missing" do
      assert {:error, "Missing or invalid channel_id"} =
        UpdateChannelPermissions.handler(%{overwrite_id: @overwrite_id, type: 0}, @agent_ctx)
    end
  end
end
