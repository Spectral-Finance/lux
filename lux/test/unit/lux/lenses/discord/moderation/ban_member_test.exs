defmodule Lux.Lenses.Discord.Moderation.BanMemberTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Discord.Moderation.BanMember

  @guild_id "123456789012345678"
  @user_id "987654321098765432"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "bans user from guild" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/v10/guilds/:guild_id/bans/:user_id"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["delete_message_seconds"] == 3600

        conn
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, result} =
               BanMember.focus(
                 %{
                   "guild_id" => @guild_id,
                   "user_id" => @user_id,
                   "delete_message_seconds" => 3600
                 },
                 %{}
               )

      assert result.banned == true
    end
  end
end
