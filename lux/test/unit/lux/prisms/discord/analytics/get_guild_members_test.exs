defmodule Lux.Prisms.Discord.Analytics.GetGuildMembersTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Discord.Analytics.GetGuildMembers

  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "fetches guild members" do
      mock_members = [
        %{"user" => %{"id" => "u1", "username" => "alice"}, "roles" => ["admin"]},
        %{"user" => %{"id" => "u2", "username" => "bob"}, "roles" => []}
      ]

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/guild123/members"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(mock_members))
      end)

      {:ok, result} = GetGuildMembers.handler(
        %{guild_id: "guild123"},
        Map.put(@agent_ctx, :plug, {Req.Test, DiscordClientMock})
      )

      assert result.count == 2
      assert length(result.members) == 2
    end

    test "returns error when guild_id is missing" do
      {:error, "Missing or invalid guild_id"} = GetGuildMembers.handler(%{}, @agent_ctx)
    end

    test "propagates API errors" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      {:error, {403, "Missing Permissions"}} =
        GetGuildMembers.handler(
          %{guild_id: "guild123"},
          Map.put(@agent_ctx, :plug, {Req.Test, DiscordClientMock})
        )
    end

    test "handles unexpected response" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!("unexpected"))
      end)

      {:error, {:unexpected_response, _}} =
        GetGuildMembers.handler(
          %{guild_id: "guild123"},
          Map.put(@agent_ctx, :plug, {Req.Test, DiscordClientMock})
        )
    end
  end
end
