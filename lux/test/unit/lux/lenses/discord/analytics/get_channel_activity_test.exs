defmodule Lux.Lenses.Discord.Analytics.GetChannelActivityTest do
  @moduledoc """
  Test suite for the GetChannelActivity module.
  These tests verify the lens's ability to:
  - Retrieve activity metrics for a Discord channel
  - Process message data into meaningful statistics
  - Handle Discord API errors appropriately
  - Validate input parameters
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Analytics.GetChannelActivity

  @channel_id "123456789012345678"
  @mock_messages [
    %{
      "id" => "111111111111111111",
      "content" => "Hello world",
      "author" => %{"id" => "222222222222222222", "username" => "User 1"},
      "timestamp" => "2024-03-28T10:00:00Z",
      "attachments" => []
    },
    %{
      "id" => "333333333333333333",
      "content" => "Check this link https://example.com",
      "author" => %{"id" => "444444444444444444", "username" => "User 2"},
      "timestamp" => "2024-03-28T10:30:00Z",
      "attachments" => []
    },
    %{
      "id" => "555555555555555555",
      "content" => "Look at this image",
      "author" => %{"id" => "222222222222222222", "username" => "User 1"},
      "timestamp" => "2024-03-28T10:00:00Z",
      "attachments" => [%{"url" => "https://example.com/image.jpg"}]
    }
  ]

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves channel activity metrics" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/channels/:channel_id/messages"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(@mock_messages))
      end)

      assert {:ok, metrics} = GetChannelActivity.focus(%{
        "channel_id" => @channel_id
      }, %{})

      # Verify basic metrics
      assert metrics.message_count == 3
      assert metrics.active_users == 2
      assert metrics.peak_hour == "10:00"

      # Verify message type distribution
      assert metrics.message_types.text == 1
      assert metrics.message_types.link == 1
      assert metrics.message_types.image == 1

      # Verify timeline
      timeline = Enum.find(metrics.activity_timeline, &(&1.hour == "10:00"))
      assert timeline.count == 3
    end

    test "handles empty channel" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/channels/:channel_id/messages"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([]))
      end)

      assert {:ok, metrics} = GetChannelActivity.focus(%{
        "channel_id" => @channel_id
      }, %{})

      assert metrics.message_count == 0
      assert metrics.active_users == 0
      assert metrics.message_types == %{text: 0, image: 0, link: 0}
      assert metrics.activity_timeline == []
      assert metrics.peak_hour == "00:00"
    end

    test "handles Discord API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/channels/:channel_id/messages"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, %{"message" => "Missing Permissions"}} = GetChannelActivity.focus(%{
        "channel_id" => @channel_id
      }, %{})
    end
  end

  describe "schema validation" do
    test "validates required fields" do
      lens = GetChannelActivity.view()
      assert lens.schema.required == ["channel_id"]
    end

    test "validates channel ID format" do
      lens = GetChannelActivity.view()
      channel_id = lens.schema.properties.channel_id
      assert channel_id.type == :string
      assert channel_id.pattern == "^[0-9]{17,20}$"
    end

    test "validates time range enum" do
      lens = GetChannelActivity.view()
      time_range = lens.schema.properties.time_range
      assert time_range.type == :string
      assert time_range.enum == ["24h", "7d", "30d"]
      assert time_range.default == "24h"
    end

    test "validates limit parameter" do
      lens = GetChannelActivity.view()
      limit = lens.schema.properties.limit
      assert limit.type == :integer
      assert limit.minimum == 1
      assert limit.maximum == 100
      assert limit.default == 100
    end
  end
end
