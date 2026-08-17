defmodule Lux.Prisms.Discord.Voice.StreamAudioTest do
  @moduledoc """
  Test suite for StreamAudio prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Voice.StreamAudio

  @guild_id "123456789012345678"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully starts audio stream" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/voice/stream"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"stream_id" => "test-stream-id"}))
      end)

      assert {:ok, %{streaming: true, guild_id: @guild_id, stream_id: stream_id}} =
               StreamAudio.handler(
                 %{
                   guild_id: @guild_id,
                   audio_source: "https://example.com/audio.opus",
                   format: "opus",
                   volume: 0.8,
                   loop: false
                 },
                 @agent_ctx
               )
    end

    test "handles missing guild_id" do
      assert {:error, "Missing or invalid guild_id"} =
               StreamAudio.handler(
                 %{
                   audio_source: "https://example.com/audio.opus"
                 },
                 @agent_ctx
               )
    end

    test "handles missing audio_source" do
      assert {:error, "Missing or invalid audio_source"} =
               StreamAudio.handler(
                 %{
                   guild_id: @guild_id
                 },
                 @agent_ctx
               )
    end
  end
end