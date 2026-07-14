defmodule Lux.Prisms.Discord.Webhook.CreateWebhookTest do
  @moduledoc false
  use UnitAPICase, async: true

  alias Lux.Prisms.Discord.Webhook.CreateWebhook
  alias Lux.Integrations.Discord.Client, as: DiscordClient

  @channel_id "123456789012345678"
  @webhook_name "Alert Bot"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2 - success" do
    test "creates a webhook with name only" do
      webhook_url = "/api/v10/channels/#{@channel_id}/webhooks"

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == webhook_url
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)
        assert parsed["name"] == @webhook_name

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "id" => "987654321098765432",
            "name" => @webhook_name,
            "channel_id" => @channel_id,
            "url" => "https://discord.com/api/webhooks/987654321098765432/test-token"
          })
        )
      end)

      assert {:ok, result} =
               CreateWebhook.handler(
                 %{
                   channel_id: @channel_id,
                   name: @webhook_name
                 },
                 @agent_ctx
               )

      assert result.webhook_id == "987654321098765432"
      assert result.name == @webhook_name
      assert result.channel_id == @channel_id
      assert result.url != nil
    end

    test "creates a webhook with avatar" do
      avatar_url = "https://example.com/avatar.png"
      webhook_url = "/api/v10/channels/#{@channel_id}/webhooks"

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == webhook_url

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)
        assert parsed["avatar"] == avatar_url

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "id" => "987654321098765432",
            "name" => @webhook_name,
            "channel_id" => @channel_id,
            "url" => "https://discord.com/api/webhooks/987654321098765432/test-token"
          })
        )
      end)

      assert {:ok, result} =
               CreateWebhook.handler(
                 %{
                   channel_id: @channel_id,
                   name: @webhook_name,
                   avatar_url: avatar_url
                 },
                 @agent_ctx
               )

      assert result.webhook_id == "987654321098765432"
    end
  end

  describe "handler/2 - errors" do
    test "returns error when channel_id is missing" do
      assert {:error, "Missing or invalid channel_id"} =
               CreateWebhook.handler(
                 %{
                   name: @webhook_name
                 },
                 @agent_ctx
               )
    end

    test "returns error when name is missing" do
      assert {:error, "Missing or invalid name (must be 1-80 characters)"} =
               CreateWebhook.handler(
                 %{
                   channel_id: @channel_id
                 },
                 @agent_ctx
               )
    end

    test "returns error when name exceeds 80 characters" do
      long_name = String.duplicate("a", 81)

      assert {:error, "Missing or invalid name (must be 1-80 characters)"} =
               CreateWebhook.handler(
                 %{
                   channel_id: @channel_id,
                   name: long_name
                 },
                 @agent_ctx
               )
    end

    test "handles Discord API error response" do
      webhook_url = "/api/v10/channels/#{@channel_id}/webhooks"

      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          403,
          Jason.encode!(%{
            "message" => "Missing Permissions"
          })
        )
      end)

      assert {:error, {403, "Missing Permissions"}} =
               CreateWebhook.handler(
                 %{
                   channel_id: @channel_id,
                   name: @webhook_name
                 },
                 @agent_ctx
               )
    end
  end
end
