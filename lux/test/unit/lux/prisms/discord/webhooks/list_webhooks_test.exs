defmodule Lux.Prisms.Discord.Webhooks.ListWebhooksTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Discord.Webhooks.ListWebhooks

  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "lists webhooks by channel_id" do
      mock_webhooks = [
        %{"id" => "wh1", "name" => "GitHub", "type" => 1},
        %{"id" => "wh2", "name" => "CI", "type" => 1}
      ]

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/channels/123456789012345678/webhooks"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(mock_webhooks))
      end)

      {:ok, result} = ListWebhooks.handler(
        %{channel_id: "123456789012345678"},
        Map.put(@agent_ctx, :plug, {Req.Test, DiscordClientMock})
      )

      assert result.count == 2
      assert length(result.webhooks) == 2
    end

    test "lists webhooks by guild_id" do
      mock_webhooks = [%{"id" => "wh1", "name" => "Bot"}]

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/123456789012345678/webhooks"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(mock_webhooks))
      end)

      {:ok, result} = ListWebhooks.handler(
        %{guild_id: "123456789012345678"},
        Map.put(@agent_ctx, :plug, {Req.Test, DiscordClientMock})
      )

      assert result.count == 1
    end

    test "returns error when neither channel_id nor guild_id provided" do
      {:error, "Missing channel_id or guild_id"} = ListWebhooks.handler(%{}, @agent_ctx)
    end

    test "propagates API errors" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      {:error, {403, "Missing Permissions"}} =
        ListWebhooks.handler(
          %{channel_id: "123456789012345678"},
          Map.put(@agent_ctx, :plug, {Req.Test, DiscordClientMock})
        )
    end
  end
end
