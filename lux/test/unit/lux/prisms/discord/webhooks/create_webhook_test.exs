defmodule Lux.Prisms.Discord.Webhooks.CreateWebhookTest do
  use ExUnit.Case
  
  alias Lux.Prisms.Discord.Webhooks.CreateWebhook

  test "exists and has correct properties" do
    assert Lux.Prisms.Discord.Webhooks.CreateWebhook.name() != nil
    assert Lux.Prisms.Discord.Webhooks.CreateWebhook.description() != nil
  end
end
