defmodule Lux.Prisms.Discord.Webhook.WebhookTest do
  @moduledoc false
  use UnitAPICase, async: false

  alias Lux.Prisms.Discord.Webhook.DeleteWebhook
  alias Lux.Prisms.Discord.Webhook.EditWebhook
  alias Lux.Prisms.Discord.Webhook.SendWebhookMessage

  @webhook_id "987654321098765432"
  @channel_id "123456789012345678"
  @agent_ctx %{name: "TestAgent"}
  @webhook_url "https://discord.com/api/webhooks/987654321098765432/test-token"

  setup do
    previous = Application.get_env(:lux, SendWebhookMessage)
    Application.put_env(:lux, SendWebhookMessage, plug: {Req.Test, __MODULE__})
    Req.Test.verify_on_exit!()

    on_exit(fn ->
      if previous do
        Application.put_env(:lux, SendWebhookMessage, previous)
      else
        Application.delete_env(:lux, SendWebhookMessage)
      end
    end)

    :ok
  end

  test "edits a webhook with PATCH and the requested JSON body" do
    Req.Test.expect(DiscordClientMock, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/api/v10/webhooks/#{@webhook_id}"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"name" => "Updated Bot"}

      Req.Test.json(conn, %{
        "id" => @webhook_id,
        "name" => "Updated Bot",
        "channel_id" => @channel_id,
        "avatar" => nil
      })
    end)

    assert {:ok, result} =
             EditWebhook.handler(%{webhook_id: @webhook_id, name: "Updated Bot"}, @agent_ctx)

    assert result == %{
             webhook_id: @webhook_id,
             name: "Updated Bot",
             channel_id: @channel_id,
             avatar_url: nil
           }
  end

  test "deletes a webhook and accepts Discord's 204 response" do
    Req.Test.expect(DiscordClientMock, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/api/v10/webhooks/#{@webhook_id}"
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, %{deleted: true, webhook_id: @webhook_id}} =
             DeleteWebhook.handler(%{webhook_id: @webhook_id}, @agent_ctx)
  end

  test "sends with wait=true and returns the Discord message id" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/webhooks/#{@webhook_id}/test-token"
      assert conn.query_string == "wait=true"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"content" => "hello"}

      Req.Test.json(conn, %{"id" => "111111111111111111", "content" => "hello"})
    end)

    assert {:ok, %{sent: true, message_id: "111111111111111111", content: "hello"}} =
             SendWebhookMessage.handler(
               %{webhook_url: @webhook_url, content: "hello"},
               @agent_ctx
             )
  end

  test "treats the wait=false 204 response as a successful silent send" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/webhooks/#{@webhook_id}/test-token"
      assert conn.query_string == "wait=false"
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, %{sent: true, message_id: nil, content: "hello"}} =
             SendWebhookMessage.handler_silent(
               %{webhook_url: @webhook_url, content: "hello"},
               @agent_ctx
             )
  end
end
