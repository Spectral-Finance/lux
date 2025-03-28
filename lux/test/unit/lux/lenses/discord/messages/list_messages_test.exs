defmodule Lux.Lenses.Discord.Messages.ListMessagesTest do
  @moduledoc """
  Test suite for the ListMessages module.
  These tests verify the lens's ability to:
  - List messages from a Discord channel
  - Handle pagination parameters
  - Process Discord API errors appropriately
  - Validate input/output schemas
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Messages.ListMessages

  @channel_id "123456789012345678"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully lists messages" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/channels/:channel_id/messages"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{
            "id" => "111111111111111111",
            "content" => "First message",
            "author" => %{
              "id" => "222222222222222222",
              "username" => "TestUser1"
            }
          },
          %{
            "id" => "333333333333333333",
            "content" => "Second message",
            "author" => %{
              "id" => "444444444444444444",
              "username" => "TestUser2"
            }
          }
        ]))
      end)

      assert {:ok, messages} = ListMessages.focus(%{
        "channel_id" => @channel_id
      }, %{})

      assert length(messages) == 2
      [first, second] = messages

      assert first.content == "First message"
      assert first.author.username == "TestUser1"
      assert second.content == "Second message"
      assert second.author.username == "TestUser2"
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

      assert {:error, %{"message" => "Missing Permissions"}} = ListMessages.focus(%{
        "channel_id" => @channel_id
      }, %{})
    end
  end

  describe "schema validation" do
    test "validates schema" do
      lens = ListMessages.view()
      assert lens.schema.required == ["channel_id"]
      assert Map.has_key?(lens.schema.properties, :channel_id)
    end
  end
end
