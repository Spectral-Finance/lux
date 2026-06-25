defmodule Lux.Prisms.Discord.Voice.UpdateVoiceStateTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Discord.Voice.UpdateVoiceState

  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "joins a voice channel" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/guilds/guild123/voice-states/@me"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{}))
      end)

      {:ok, result} = UpdateVoiceState.handler(
        %{guild_id: "guild123", channel_id: "channel456"},
        Map.put(@agent_ctx, :plug, {Req.Test, DiscordClientMock})
      )

      assert result.joined == true
      assert result.disconnected == false
      assert result.guild_id == "guild123"
      assert result.channel_id == "channel456"
    end

    test "disconnects from voice channel" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{}))
      end)

      {:ok, result} = UpdateVoiceState.handler(
        %{guild_id: "guild123", channel_id: nil},
        Map.put(@agent_ctx, :plug, {Req.Test, DiscordClientMock})
      )

      assert result.joined == false
      assert result.disconnected == true
      assert result.channel_id == nil
    end

    test "returns error when guild_id is missing" do
      {:error, "Missing or invalid guild_id"} = UpdateVoiceState.handler(%{}, @agent_ctx)
    end

    test "returns error when guild_id is empty" do
      {:error, "Missing or invalid guild_id"} = UpdateVoiceState.handler(%{guild_id: ""}, @agent_ctx)
    end

    test "propagates API errors" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      {:error, {403, "Missing Permissions"}} =
        UpdateVoiceState.handler(
          %{guild_id: "guild123", channel_id: "channel456"},
          Map.put(@agent_ctx, :plug, {Req.Test, DiscordClientMock})
        )
    end
  end
end
