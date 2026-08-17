defmodule Lux.Prisms.Discord.Events.SetEventReminderTest do
  @moduledoc """
  Test suite for SetEventReminder prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Events.SetEventReminder

  @guild_id "123456789012345678"
  @event_id "222222222222222222"
  @channel_id "333333333333333333"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sets event reminder" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/scheduled-events/#{@event_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @event_id,
          "name" => "Test Event",
          "scheduled_start_time" => "2026-08-15T20:00:00Z",
          "guild_id" => @guild_id
        }))
      end)

      assert {:ok, %{
        reminder_set: true,
        guild_id: @guild_id,
        event_id: @event_id,
        channel_id: @channel_id,
        trigger_at: trigger_at,
        reminder_id: reminder_id
      }} = SetEventReminder.handler(
        %{
          guild_id: @guild_id,
          event_id: @event_id,
          reminder_before_seconds: 3600,
          channel_id: @channel_id,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      ) when is_binary(trigger_at) and String.starts_with?(reminder_id, "remind_")

      assert String.starts_with?(reminder_id, "remind_")
      assert is_binary(trigger_at)
    end
  end
end