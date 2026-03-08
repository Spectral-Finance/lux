defmodule Lux.Prisms.Telegram.ManageWebhookTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Telegram.ManageWebhook

  setup do
    Req.Test.stub(Lux.Telegram.WebhookMock, fn conn ->
      Req.Test.json(conn, %{"ok" => true, "result" => true})
    end)

    Req.Test.stub(Lux.Telegram.WebhookInfoMock, fn conn ->
      Req.Test.json(conn, %{
        "ok" => true,
        "result" => %{
          "url" => "https://example.com/webhook",
          "has_custom_certificate" => false,
          "pending_update_count" => 0
        }
      })
    end)

    :ok
  end

  test "sets webhook" do
    assert {:ok, true} =
             ManageWebhook.handler(
               %{action: "set", url: "https://example.com/webhook", token: "t", plug: {Req.Test, Lux.Telegram.WebhookMock}},
               []
             )
  end

  test "deletes webhook" do
    assert {:ok, true} =
             ManageWebhook.handler(
               %{action: "delete", token: "t", plug: {Req.Test, Lux.Telegram.WebhookMock}},
               []
             )
  end

  test "gets webhook info" do
    assert {:ok, result} =
             ManageWebhook.handler(
               %{action: "info", token: "t", plug: {Req.Test, Lux.Telegram.WebhookInfoMock}},
               []
             )

    assert result["url"] == "https://example.com/webhook"
  end
end
