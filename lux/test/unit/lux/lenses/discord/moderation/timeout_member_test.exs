defmodule Lux.Lenses.Discord.Moderation.TimeoutMemberTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Discord.Moderation.TimeoutMember

  @guild_id "123456789012345678"
  @user_id "987654321098765432"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "sets member timeout" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/guilds/:guild_id/members/:user_id"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["communication_disabled_until"] == "2026-11-02T13:00:00Z"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "user" => %{"id" => @user_id},
            "communication_disabled_until" => "2026-11-02T13:00:00Z"
          })
        )
      end)

      assert {:ok, result} =
               TimeoutMember.focus(
                 %{
                   "guild_id" => @guild_id,
                   "user_id" => @user_id,
                   "communication_disabled_until" => "2026-11-02T13:00:00Z"
                 },
                 %{}
               )

      assert result.user_id == @user_id
      assert result.communication_disabled_until == "2026-11-02T13:00:00Z"
    end
  end
end
