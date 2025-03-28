defmodule Lux.Lenses.Discord.Channels.ReadChannelTest do
  @moduledoc """
  Test suite for the ReadChannel module.
  These tests verify the lens's ability to:
  - Read channel information from Discord
  - Handle Discord API errors appropriately
  - Validate input/output schemas
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Channels.ReadChannel

  @channel_id "123456789012345678"
  @guild_id "987654321098765432"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully reads a channel" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/channels/:channel_id"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @channel_id,
          "guild_id" => @guild_id,
          "name" => "general",
          "type" => 0
        }))
      end)

      assert {:ok, %{
        id: @channel_id,
        guild_id: @guild_id,
        name: "general",
        type: 0
      }} = ReadChannel.focus(%{
        "channel_id" => @channel_id
      }, %{})
    end

    test "handles Discord API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/channels/:channel_id"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, %{"message" => "Missing Permissions"}} = ReadChannel.focus(%{
        "channel_id" => @channel_id
      }, %{})
    end
  end

  describe "schema validation" do
    test "validates schema" do
      lens = ReadChannel.view()
      assert lens.schema.required == ["channel_id"]
      assert Map.has_key?(lens.schema.properties, :channel_id)
    end
  end
end
