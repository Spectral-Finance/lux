defmodule Lux.Prisms.Discord.Webhook.ExecuteWebhookTest do
  @moduledoc """
  Test suite for ExecuteWebhook prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Webhook.ExecuteWebhook

  @webhook_id "123456789012345678"
  @token "test-token-abc123"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully executes webhook with content" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/webhooks/#{@webhook_id}/#{@token}?wait=true"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body)["content"] == "Test message"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "987654321098765432",
          "channel_id" => "111111111111111111"
        }))
      end)

      assert {:ok, %{sent: true, message_id: "987654321098765432", channel_id: "111111111111111111"}} =
               ExecuteWebhook.handler(
                 %{
                   webhook_id: @webhook_id,
                   token: @token,
                   content: "Test message",
                   wait: true
                 },
                 @agent_ctx
               )
    end

    test "executes webhook with embeds" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body)["embeds"][0]["title"] == "Test Embed"

        conn
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{sent: true}} =
               ExecuteWebhook.handler(
                 %{
                   webhook_id: @webhook_id,
                   token: @token,
                   embeds: [%{title: "Test Embed", color: 16777215}]
                 },
                 @agent_ctx
               )
    end

    test "handles rate limit with retry" do
      call_count = :ets.new(:counter, [:public, :named_table])
      :ets.insert(call_count, {:count, 0})

      Req.Test.expect(DiscordClientMock, fn conn ->
        count = elem(:ets.lookup(call_count, :count), 1) |> elem(1)
        :ets.insert(call_count, {:count, count + 1})
        
        if count == 0 do
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(429, Jason.encode!(%{"retry_after" => 100}))
        else
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "987654321098765432"}))
        end
      end)

      assert {:ok, %{sent: true}} =
               ExecuteWebhook.handler(
                 %{
                   webhook_id: @webhook_id,
                   token: @token,
                   content: "Test"
                 },
                 @agent_ctx
               )
    end
  end
end