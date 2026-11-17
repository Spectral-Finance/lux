defmodule Lux.Lenses.Discord.Moderation.GetAuditLogTest do
  @moduledoc """
  Test suite for the GetAuditLog module.
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Moderation.GetAuditLog

  @guild_id "123456789012345678"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully fetches audit log" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/:guild_id/audit-logs"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "audit_log_entries" => [
            %{
              "id" => "111111111111111111",
              "action_type" => 22,
              "user_id" => "222222222222222222",
              "target_id" => "333333333333333333",
              "reason" => "Spam"
            }
          ]
        }))
      end)

      assert {:ok, %{entries: entries}} = GetAuditLog.focus(%{guild_id: @guild_id}, %{})
      assert length(entries) == 1
      [entry] = entries
      assert entry.id == "111111111111111111"
      assert entry.action_type == 22
      assert entry.user_id == "222222222222222222"
      assert entry.reason == "Spam"
    end

    test "handles Discord API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, %{"message" => "Missing Permissions"}} =
        GetAuditLog.focus(%{guild_id: @guild_id}, %{})
    end
  end
end
