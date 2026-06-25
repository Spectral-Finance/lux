defmodule Lux.Prisms.Discord.Analytics.GetAuditLogTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Discord.Analytics.GetAuditLog

  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "fetches audit log entries" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/guild123/audit-logs"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "audit_log_entries" => [
            %{"id" => "1", "action_type" => 1, "target_id" => "123", "user_id" => "456"}
          ],
          "users" => [%{"id" => "456", "username" => "admin"}],
          "integrations" => []
        }))
      end)

      {:ok, result} = GetAuditLog.handler(
        %{guild_id: "guild123"},
        Map.put(@agent_ctx, :plug, {Req.Test, DiscordClientMock})
      )

      assert length(result.entries) == 1
      assert length(result.users) == 1
    end

    test "returns error when guild_id is missing" do
      {:error, "Missing or invalid guild_id"} = GetAuditLog.handler(%{}, @agent_ctx)
    end

    test "returns error when guild_id is empty" do
      {:error, "Missing or invalid guild_id"} = GetAuditLog.handler(%{guild_id: ""}, @agent_ctx)
    end

    test "propagates API errors" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      {:error, {403, "Missing Permissions"}} =
        GetAuditLog.handler(
          %{guild_id: "guild123"},
          Map.put(@agent_ctx, :plug, {Req.Test, DiscordClientMock})
        )
    end
  end
end
