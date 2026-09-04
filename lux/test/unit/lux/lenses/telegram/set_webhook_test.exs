defmodule Lux.Lenses.Telegram.SetWebhookTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Telegram.SetWebhook

  describe "before_focus/1 and schema" do
    test "transforms :url param to string key url" do
      params = %{url: "https://example.com/webhook", secret_token: "secret123"}
      transformed = SetWebhook.before_focus(params)
      assert transformed["url"] == "https://example.com/webhook"
      assert transformed[:secret_token] == "secret123"

      # When no :url key
      params2 = %{"url" => "https://example.com/webhook"}
      assert SetWebhook.before_focus(params2) == %{"url" => "https://example.com/webhook"}

      # Non-map passthrough
      assert SetWebhook.before_focus("not_map") == "not_map"
    end

    test "view/0 returns lens schema" do
      lens = SetWebhook.view()
      assert lens.name == "SetWebhook"
      assert lens.method == :post
      assert lens.schema.properties.url.type == :string
    end
  end
end
