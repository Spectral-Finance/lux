defmodule Lux.Prisms.Discord.Moderation.TimeoutMemberTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Discord.Moderation.TimeoutMember

  @guild_id "123456789012345678"
  @user_id "987654321098765432"
  @until_iso8601 "2026-06-15T12:30:00Z"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "applies a member timeout with an audit log reason" do
    Req.Test.expect(DiscordClientMock, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "PATCH"
      assert conn.request_path == "/api/v10/guilds/#{@guild_id}/members/#{@user_id}"
      assert Plug.Conn.get_req_header(conn, "x-audit-log-reason") == ["spam%20campaign"]
      assert Jason.decode!(body) == %{"communication_disabled_until" => @until_iso8601}

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"user" => %{"id" => @user_id}}))
    end)

    assert {:ok,
            %{
              timed_out: true,
              guild_id: @guild_id,
              user_id: @user_id,
              communication_disabled_until: @until_iso8601
            }} =
             TimeoutMember.handler(
               %{
                 guild_id: @guild_id,
                 user_id: @user_id,
                 until_iso8601: @until_iso8601,
                 reason: "spam campaign"
               },
               %{name: "Moderator"}
             )
  end

  test "requires an end time or duration" do
    assert {:error, "Missing until_iso8601 or positive duration_seconds"} =
             TimeoutMember.handler(%{guild_id: @guild_id, user_id: @user_id}, %{})
  end
end
