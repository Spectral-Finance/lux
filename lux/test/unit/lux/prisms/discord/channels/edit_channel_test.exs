defmodule Lux.Prisms.Discord.Channels.EditChannelTest do
  @moduledoc """
  Tests for the EditChannel prism which modifies Discord channel settings.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Channels.EditChannel

  @channel_id "123456789012345678"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully edits a channel" do
      channel_name = "new-channel-name"
      channel_topic = "New channel topic"

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @channel_id,
          "name" => channel_name,
          "topic" => channel_topic,
          "type" => 0
        }))
      end)

      assert {:ok, response} =
               EditChannel.handler(%{
                 "channel_id" => @channel_id,
                 "name" => channel_name,
                 "topic" => channel_topic
               }, @agent_ctx)

      assert response.channel_id == @channel_id
      assert response.name == channel_name
      assert response.topic == channel_topic
      assert response.edited == true
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions",
          "code" => 50_013
        }))
      end)

      assert {:error, {403, "Missing Permissions"}} =
               EditChannel.handler(%{
                 "channel_id" => @channel_id,
                 "name" => "new-name"
               }, @agent_ctx)
    end
  end

  describe "schema validation" do
    test "validates required properties" do
      assert %{
               "type" => "object",
               "required" => ["channel_id"],
               "properties" => %{
                 "channel_id" => %{"type" => "string", "pattern" => "^\\d{17,20}$"},
                 "name" => %{"type" => "string", "minLength" => 1, "maxLength" => 100},
                 "topic" => %{"type" => "string", "maxLength" => 1024},
                 "bitrate" => %{"type" => "integer", "minimum" => 8000},
                 "user_limit" => %{"type" => "integer", "minimum" => 0},
                 "nsfw" => %{"type" => "boolean"}
               }
             } = EditChannel.input_schema()

      assert %{
               "type" => "object",
               "required" => ["channel_id", "edited"],
               "properties" => %{
                 "channel_id" => %{"type" => "string"},
                 "name" => %{"type" => "string"},
                 "topic" => %{"type" => "string"},
                 "edited" => %{"type" => "boolean"}
               }
             } = EditChannel.output_schema()
    end
  end
end
