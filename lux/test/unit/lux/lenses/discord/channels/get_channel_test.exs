defmodule Lux.Lenses.Discord.Channels.GetChannelTest do
  @moduledoc """
  Test suite for the GetChannel module.
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Channels.GetChannel

  @channel_id "123456789012345678"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully fetches channel details" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/channels/:channel_id"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @channel_id,
          "name" => "general",
          "type" => 0,
          "guild_id" => "987654321098765432",
          "position" => 1,
          "topic" => "General discussion",
          "nsfw" => false,
          "permission_overwrites" => []
        }))
      end)

      assert {:ok, channel} = GetChannel.focus(%{channel_id: @channel_id}, %{})
      assert channel.id == @channel_id
      assert channel.name == "general"
      assert channel.type == 0
      assert channel.guild_id == "987654321098765432"
      assert channel.topic == "General discussion"
    end

    test "handles Discord API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "message" => "Unknown Channel"
        }))
      end)

      assert {:error, %{"message" => "Unknown Channel"}} =
        GetChannel.focus(%{channel_id: @channel_id}, %{})
    end
  end
end
