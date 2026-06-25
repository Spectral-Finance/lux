defmodule Lux.Integrations.Discord.WebhooksTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Discord.Webhooks

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "creates a Discord webhook" do
    Req.Test.expect(DiscordClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/v10/channels/123456789012345678/webhooks"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"name" => "deployments"}

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        201,
        Jason.encode!(%{"id" => "987654321098765432", "name" => "deployments"})
      )
    end)

    assert {:ok, %{"id" => "987654321098765432"}} =
             Webhooks.create("123456789012345678", %{name: "deployments"})
  end

  test "retries rate-limited webhook requests" do
    Req.Test.expect(DiscordClientMock, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(429, Jason.encode!(%{"message" => "Too many requests"}))
    end)

    Req.Test.expect(DiscordClientMock, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "987654321098765432"}))
    end)

    assert {:ok, %{"id" => "987654321098765432"}} =
             Webhooks.update(
               "987654321098765432",
               %{name: "alerts"},
               %{retries: 1, retry_delay_ms: 0}
             )
  end

  test "executes a Discord webhook and waits for the message response" do
    Req.Test.expect(DiscordClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/v10/webhooks/987654321098765432/token-123"
      assert conn.query_string == "wait=true"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"content" => "Build passed"}

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "111111111111111111"}))
    end)

    assert {:ok, %{"id" => "111111111111111111"}} =
             Webhooks.execute("987654321098765432", "token-123", %{content: "Build passed"})
  end
end
