defmodule Lux.Lenses.Discord.Guild.AuditLogsTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Discord.Guild.AuditLogs

  @guild_id "123456789012345678"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "reads guild audit log entries for activity monitoring" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/:guild_id/audit-logs"

        query = URI.decode_query(conn.query_string)
        assert query["guild_id"] == @guild_id
        assert query["limit"] == "10"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "audit_log_entries" => [
              %{
                "id" => "111111111111111111",
                "action_type" => 10,
                "user_id" => "222222222222222222",
                "target_id" => "333333333333333333",
                "reason" => "cleanup"
              }
            ],
            "users" => [
              %{"id" => "222222222222222222", "username" => "Moderator"}
            ]
          })
        )
      end)

      assert {:ok, %{entries: [entry], users: [user]}} =
               AuditLogs.focus(%{guild_id: @guild_id, limit: 10}, %{})

      assert entry.id == "111111111111111111"
      assert entry.action_type == 10
      assert user.username == "Moderator"
    end

    test "handles Discord API errors" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/:guild_id/audit-logs"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      assert {:error, %{"message" => "Missing Permissions"}} =
               AuditLogs.focus(%{guild_id: @guild_id}, %{})
    end
  end
end
