defmodule Lux.Lenses.Discord.Channels.SetPermissionsTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Discord.Channels.SetPermissions

  @channel_id "123456789012345678"
  @overwrite_id "987654321098765432"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "sets channel permission overwrite" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/v10/channels/:channel_id/permissions/:overwrite_id"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["type"] == 0
        assert decoded["allow"] == "1024"

        conn
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, result} =
               SetPermissions.focus(
                 %{
                   "channel_id" => @channel_id,
                   "overwrite_id" => @overwrite_id,
                   "type" => 0,
                   "allow" => "1024",
                   "deny" => "0"
                 },
                 %{}
               )

      assert result.status == :ok
    end
  end
end
