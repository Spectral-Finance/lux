defmodule Lux.Lenses.Discord.Pins.GetPinnedMessagesTest do
  @moduledoc """
  Test suite for the GetPinnedMessages lens.
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Pins.GetPinnedMessages

  @channel_id "123456789012345678"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves pinned messages" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{
            "id" => "111111111111111111",
            "content" => "Important pinned message",
            "channel_id" => @channel_id,
            "author" => %{"id" => "987654321098765432"},
            "timestamp" => "2026-02-01T12:00:00Z"
          }
        ]))
      end)

      assert {:ok, [%{
        id: "111111111111111111",
        content: "Important pinned message",
        channel_id: @channel_id,
        author_id: "987654321098765432",
        timestamp: "2026-02-01T12:00:00Z"
      }]} = GetPinnedMessages.focus(%{"channel_id" => @channel_id}, %{})
    end

    test "returns empty list when no pinned messages" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([]))
      end)

      assert {:ok, []} = GetPinnedMessages.focus(%{"channel_id" => @channel_id}, %{})
    end

    test "handles Discord API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Access"}))
      end)

      assert {:error, %{"message" => "Missing Access"}} =
        GetPinnedMessages.focus(%{"channel_id" => @channel_id}, %{})
    end
  end
end
