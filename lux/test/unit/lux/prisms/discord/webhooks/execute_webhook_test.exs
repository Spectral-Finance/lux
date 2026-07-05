defmodule Lux.Prisms.Discord.Webhooks.ExecuteWebhookTest do
  use ExUnit.Case
  
  alias Lux.Prisms.Discord.Webhooks.ExecuteWebhook

  test "exists and has correct properties" do
    assert Lux.Prisms.Discord.Webhooks.ExecuteWebhook.name() != nil
    assert Lux.Prisms.Discord.Webhooks.ExecuteWebhook.description() != nil
  end
end
