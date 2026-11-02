defmodule Lux.Lenses.Discord.Channels.DeleteChannelTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Discord.Channels.DeleteChannel

  @channel_id "123456789012345678"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "deletes channel" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/channels/:channel_id"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{"id" => @channel_id, "name" => "deleted-chan"})
        )
      end)

      assert {:ok, result} =
               DeleteChannel.focus(%{"channel_id" => @channel_id}, %{})

      assert result.id == @channel_id
      assert result.deleted == true
    end
  end
end
