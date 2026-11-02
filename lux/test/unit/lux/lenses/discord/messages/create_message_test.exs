defmodule Lux.Lenses.Discord.Messages.CreateMessageTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Discord.Messages.CreateMessage

  @channel_id "123456789012345678"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "creates message in channel" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/channels/:channel_id/messages"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["content"] == "Hello Discord!"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "id" => "999000111222333444",
            "channel_id" => @channel_id,
            "content" => decoded["content"],
            "author" => %{"id" => "bot_id", "username" => "LuxBot"},
            "timestamp" => "2026-11-02T12:00:00Z"
          })
        )
      end)

      assert {:ok, result} =
               CreateMessage.focus(
                 %{"channel_id" => @channel_id, "content" => "Hello Discord!"},
                 %{}
               )

      assert result.id == "999000111222333444"
      assert result.content == "Hello Discord!"
    end

    test "validates required parameters" do
      assert {:error, errors} = CreateMessage.focus(%{})
      assert is_list(errors)
    end
  end
end
