defmodule Lux.Lenses.Discord.Channels.ModifyChannelTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Discord.Channels.ModifyChannel

  @channel_id "123456789012345678"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "modifies channel topic and slowmode" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/channels/:channel_id"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["topic"] == "New Topic"
        assert decoded["rate_limit_per_user"] == 15

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "id" => @channel_id,
            "name" => "general",
            "topic" => decoded["topic"],
            "rate_limit_per_user" => decoded["rate_limit_per_user"]
          })
        )
      end)

      assert {:ok, result} =
               ModifyChannel.focus(
                 %{
                   "channel_id" => @channel_id,
                   "topic" => "New Topic",
                   "rate_limit_per_user" => 15
                 },
                 %{}
               )

      assert result.topic == "New Topic"
      assert result.rate_limit_per_user == 15
    end
  end
end
