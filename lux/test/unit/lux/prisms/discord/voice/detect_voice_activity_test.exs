defmodule Lux.Prisms.Discord.Voice.DetectVoiceActivityTest do
  @moduledoc """
  Test suite for DetectVoiceActivity prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Voice.DetectVoiceActivity

  @guild_id "123456789012345678"
  @channel_id "223456789012345678"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully starts voice activity monitoring" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/voice-states"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{"user_id" => "323456789012345678", "channel_id" => @channel_id, "speaking" => true, "self_mute" => false},
          %{"user_id" => "423456789012345678", "channel_id" => @channel_id, "speaking" => false, "self_mute" => false}
        ]))
      end)

      assert {:ok, %{monitoring: true, guild_id: @guild_id, channel_id: @channel_id, active_speakers: speakers}} =
               DetectVoiceActivity.handler(
                 %{
                   guild_id: @guild_id,
                   channel_id: @channel_id,
                   threshold: 0.5,
                   interval_ms: 1000
                 },
                 @agent_ctx
               )
      
      assert length(speakers) == 2
    end

    test "handles API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      assert {:error, {403, "Missing Permissions"}} =
               DetectVoiceActivity.handler(
                 %{
                   guild_id: @guild_id,
                   channel_id: @channel_id
                 },
                 @agent_ctx
               )
    end
  end
end