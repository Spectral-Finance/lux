defmodule Lux.Prisms.Discord.Channels.MuteChannelTest do
  @moduledoc """
  Test suite for the MuteChannel module.
  These tests verify the prism's ability to:
  - Mute notifications for a Discord channel
  - Handle different mute durations
  - Handle Discord API errors appropriately
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Channels.MuteChannel

  @channel_id "123456789012345678"
  @guild_id "987654321098765432"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully mutes a channel for 1 hour" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/users/@me/guilds/#{@guild_id}/channels/#{@channel_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)

        # Compare only up to seconds to avoid microsecond differences
        assert %{"muted" => true} = body_map
        assert String.match?(body_map["mute_end_time"], ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)

        # Verify the mute_end_time is approximately 1 hour from now
        {:ok, mute_end, _} = DateTime.from_iso8601(body_map["mute_end_time"])
        now = DateTime.utc_now()
        diff = DateTime.diff(mute_end, now)
        assert_in_delta diff, 3600, 1

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, body)
      end)

      assert {:ok, %{
        muted: true,
        channel_id: @channel_id,
        guild_id: @guild_id,
        duration: 3600
      }} = MuteChannel.handler(
        %{
          channel_id: @channel_id,
          guild_id: @guild_id,
          duration: 3600,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "successfully mutes a channel indefinitely" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/users/@me/guilds/#{@guild_id}/channels/#{@channel_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{
          "muted" => true,
          "mute_end_time" => nil
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, body)
      end)

      assert {:ok, %{
        muted: true,
        channel_id: @channel_id,
        guild_id: @guild_id,
        duration: nil
      }} = MuteChannel.handler(
        %{
          channel_id: @channel_id,
          guild_id: @guild_id,
          duration: nil,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/users/@me/guilds/#{@guild_id}/channels/#{@channel_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, {403, "Missing Permissions"}} = MuteChannel.handler(
        %{
          channel_id: @channel_id,
          guild_id: @guild_id,
          duration: 3600,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = MuteChannel.view()
      assert prism.input_schema.required == ["channel_id", "guild_id"]
      assert Map.has_key?(prism.input_schema.properties, :channel_id)
      assert Map.has_key?(prism.input_schema.properties, :guild_id)
      assert Map.has_key?(prism.input_schema.properties, :duration)
    end

    test "validates output schema" do
      prism = MuteChannel.view()
      assert prism.output_schema.required == ["muted"]
      assert Map.has_key?(prism.output_schema.properties, :muted)
      assert Map.has_key?(prism.output_schema.properties, :channel_id)
      assert Map.has_key?(prism.output_schema.properties, :guild_id)
      assert Map.has_key?(prism.output_schema.properties, :duration)
    end
  end
end
