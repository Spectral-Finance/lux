defmodule Lux.Prisms.Discord.Webhooks.CreateWebhookTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Discord.Webhooks.CreateWebhook

  @channel_id "123456789012345678"
  @webhook_id "987654321098765432"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "successfully creates a webhook" do
    Req.Test.expect(DiscordClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/v10/channels/#{@channel_id}/webhooks"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"name" => "deployments"}

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        201,
        Jason.encode!(%{
          "id" => @webhook_id,
          "channel_id" => @channel_id,
          "name" => "deployments",
          "token" => "token-123"
        })
      )
    end)

    assert {:ok,
            %{
              created: true,
              webhook_id: @webhook_id,
              channel_id: @channel_id,
              name: "deployments",
              token: "token-123"
            }} =
             CreateWebhook.handler(
               %{channel_id: @channel_id, name: "deployments"},
               %{agent: %{name: "TestAgent"}}
             )
  end

  test "handles Discord API errors" do
    Req.Test.expect(DiscordClientMock, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
    end)

    assert {:error, {403, "Missing Permissions"}} =
             CreateWebhook.handler(%{channel_id: @channel_id, name: "deployments"}, %{})
  end
end
