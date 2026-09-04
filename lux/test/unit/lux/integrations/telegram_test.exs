defmodule Lux.Integrations.TelegramTest do
  use UnitAPICase, async: false

  alias Lux.Integrations.Telegram
  import Mock

  describe "settings and headers" do
    test "request_settings returns expected map" do
      settings = Telegram.request_settings()
      assert is_map(settings)
      assert settings[:headers] == [{"Content-Type", "application/json"}]
      assert is_map(settings[:auth])
    end

    test "headers returns content-type header" do
      assert Telegram.headers() == [{"Content-Type", "application/json"}]
    end

    test "auth returns custom auth map" do
      auth = Telegram.auth()
      assert auth.type == :custom
      assert is_function(auth.auth_function, 1)
    end
  end

  describe "add_auth_header/1 with Lux.Lens" do
    test "interpolates token in url containing /bot{token}/" do
      lens = %Lux.Lens{url: "https://api.telegram.org/bot{token}/sendMessage", params: %{token: "my_token"}}
      updated = Telegram.add_auth_header(lens)
      assert updated.url == "https://api.telegram.org/botmy_token/sendMessage"
    end

    test "interpolates token in url containing /bot/" do
      lens = %Lux.Lens{url: "https://api.telegram.org/bot/sendMessage", params: %{token: "my_token"}}
      updated = Telegram.add_auth_header(lens)
      assert updated.url == "https://api.telegram.org/botmy_token/sendMessage"
    end

    test "leaves url untouched if no bot placeholder" do
      lens = %Lux.Lens{url: "https://api.telegram.org/custom/path", params: %{token: "my_token"}}
      updated = Telegram.add_auth_header(lens)
      assert updated.url == "https://api.telegram.org/custom/path"
    end

    test "handles nil url gracefully" do
      lens = %Lux.Lens{url: nil, params: %{token: "my_token"}}
      updated = Telegram.add_auth_header(lens)
      assert updated.url == ""
    end
  end

  describe "add_auth_header/1 with Plug.Conn" do
    test "interpolates token in request_path containing /bot{token}/" do
      conn = %Plug.Conn{request_path: "/bot{token}/webhook"}
      with_mock Lux.Config, [:passthrough], [telegram_bot_token: fn -> "config_token" end] do
        updated = Telegram.add_auth_header(conn)
        assert updated.request_path == "/botconfig_token/webhook"
      end
    end

    test "interpolates token in request_path containing /bot/" do
      conn = %Plug.Conn{request_path: "/bot/webhook"}
      with_mock Lux.Config, [:passthrough], [telegram_bot_token: fn -> "config_token" end] do
        updated = Telegram.add_auth_header(conn)
        assert updated.request_path == "/botconfig_token/webhook"
      end
    end

    test "leaves request_path untouched if no bot placeholder" do
      conn = %Plug.Conn{request_path: "/custom/webhook"}
      updated = Telegram.add_auth_header(conn)
      assert updated.request_path == "/custom/webhook"
    end

    test "handles nil request_path gracefully" do
      conn = %Plug.Conn{request_path: nil}
      updated = Telegram.add_auth_header(conn)
      assert updated.request_path == ""
    end
  end

  describe "fetch_token/1" do
    test "fetches token from atom key in map" do
      assert Telegram.fetch_token(%{token: "atom_token"}) == "atom_token"
    end

    test "fetches token from string key in map" do
      assert Telegram.fetch_token(%{"token" => "string_token"}) == "string_token"
    end

    test "fetches token from keyword list" do
      assert Telegram.fetch_token([token: "kw_token"]) == "kw_token"
    end

    test "falls back to Lux.Config when opts empty" do
      with_mock Lux.Config, [:passthrough], [telegram_bot_token: fn -> "cfg_token" end] do
        assert Telegram.fetch_token(%{}) == "cfg_token"
      end
    end

    test "falls back to System env when config raises or returns nil" do
      System.put_env("TELEGRAM_BOT_TOKEN", "env_token_123")

      with_mock Lux.Config, [:passthrough], [telegram_bot_token: fn -> nil end] do
        assert Telegram.fetch_token(%{}) == "env_token_123"
        assert Telegram.fetch_token([other: "val"]) == "env_token_123"
        assert Telegram.fetch_token(:invalid_non_map) == "env_token_123"
      end

      with_mock Lux.Config, [:passthrough], [telegram_bot_token: fn -> raise "Config lookup error" end] do
        assert Telegram.fetch_token(%{}) == "env_token_123"
      end

      with_mock Lux.Config, [:passthrough], [telegram_bot_token: fn -> throw(:thrown_cfg) end] do
        assert Telegram.fetch_token(%{}) == "env_token_123"
      end

      System.delete_env("TELEGRAM_BOT_TOKEN")
    end
  end
end
