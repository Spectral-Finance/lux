defmodule Lux.Prisms.Discord.Webhook.CreateWebhookTest do
  @moduledoc """
  Test suite for CreateWebhook prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Webhook.CreateWebhook

  @channel_id "123456789012345678"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully creates webhook" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/webhooks"
        
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"name" => "Test Webhook"}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(%{
          "id" => "987654321098765432",
          "token" => "test-token-abc123",
          "name" => "Test Webhook",
          "channel_id" => @channel_id
        }))
      end)

      assert {:ok, %{created: true, webhook_id: "987654321098765432", token: "test-token-abc123", url: "https://discord.com/api/webhooks/987654321098765432/test-token-abc123", name: "Test Webhook", channel_id: @channel_id}} =
               CreateWebhook.handler(
                 %{
                   channel_id: @channel_id,
                   name: "Test Webhook"
                 },
                 @agent_ctx
               )
    end

    test "creates webhook with avatar and reason" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert Plug.Conn.get_req_header(conn, "x-audit-log-reason") == ["creating+webhook"]
        
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(%{
          "id" => "987654321098765432",
          "token" => "test-token-abc123",
          "name" => "Test Webhook",
          "channel_id" => @channel_id
        }))
      end)

      assert {:ok, %{created: true, webhook_id: "987654321098765432"}} =
               CreateWebhook.handler(
                 %{
                   channel_id: @channel_id,
                   name: "Test Webhook",
                   avatar: "base64-avatar-data",
                   reason: "creating webhook"
                 },
                 @agent_ctx
               )
    end
  end
end