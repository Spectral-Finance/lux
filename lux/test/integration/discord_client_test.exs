defmodule Lux.Integration.Discord.ClientTest do
  use IntegrationCase, async: true

  alias Lux.Integrations.Discord.Client

  describe "basic Discord API integration" do
    setup do
      config = %{
        api_key: Application.get_env(:lux, :api_keys)[:integration_discord]
      }

      %{config: config}
    end

    test "can fetch current bot user information", %{config: config} do
      assert {:ok, %{
        "accent_color" => _,
        "avatar" => _,
        "avatar_decoration_data" => _,
        "banner" => _,
        "banner_color" => _,
        "bio" => _,
        "bot" => _,
        "clan" => _,
        "collectibles" => _,
        "discriminator" => _,
        "email" => _,
        "flags" => _,
        "global_name" => _,
        "id" => _,
        "locale" => _,
        "mfa_enabled" => _,
        "premium_type" => _,
        "primary_guild" => _,
        "public_flags" => _,
        "username" => "bot" <> _,
        "verified" => _
      }} = Client.request(:get, "/users/@me")
    end
  end
end
