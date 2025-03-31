defmodule Lux.Integration.Telegram.ClientTest do
  use IntegrationCase, async: true

  alias Lux.Integrations.Telegram.Client

  describe "basic Telegram API integration" do
    test "can fetch current bot information" do
      assert {:ok, %{
        "ok" => true,
        "result" => %{
          "id" => _,
          "is_bot" => true,
          "first_name" => _,
          "username" => _,
          "can_join_groups" => _,
          "can_read_all_group_messages" => _,
          "supports_inline_queries" => _
        }
      }} = Client.request(:get, "/getMe")
    end
  end
end
