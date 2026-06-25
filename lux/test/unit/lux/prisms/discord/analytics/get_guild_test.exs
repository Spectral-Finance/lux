defmodule Lux.Prisms.Discord.Analytics.GetGuildTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Discord.Analytics.GetGuild

  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "fetches guild information" do
      mock_guild = %{"id" => "guild123", "name" => "Test Server", "member_count" => 500}

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ "/api/v10/guilds/guild123"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(mock_guild))
      end)

      {:ok, result} = GetGuild.handler(
        %{guild_id: "guild123"},
        Map.put(@agent_ctx, :plug, {Req.Test, DiscordClientMock})
      )

      assert result.guild["name"] == "Test Server"
      assert result.guild["member_count"] == 500
    end

    test "returns error when guild_id is missing" do
      {:error, "Missing or invalid guild_id"} = GetGuild.handler(%{}, @agent_ctx)
    end

    test "propagates API errors" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"message" => "Unknown Guild"}))
      end)

      {:error, {404, "Unknown Guild"}} =
        GetGuild.handler(
          %{guild_id: "guild123"},
          Map.put(@agent_ctx, :plug, {Req.Test, DiscordClientMock})
        )
    end
  end
end
