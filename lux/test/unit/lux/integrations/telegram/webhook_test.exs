defmodule Lux.Integrations.Telegram.WebhookTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.Webhook

  describe "verify_secret_token/2" do
    test "returns true when tokens match" do
      assert Webhook.verify_secret_token("my-secret", "my-secret") == true
    end

    test "returns false when tokens do not match" do
      assert Webhook.verify_secret_token("header-val", "expected-secret") == false
    end

    test "returns false when token lengths do not match (no crash)" do
      assert Webhook.verify_secret_token("short", "much-longer-expected-secret") == false
      assert Webhook.verify_secret_token("much-longer-expected-secret", "short") == false
    end

    test "extracts secret token from Plug.Conn" do
      conn =
        %Plug.Conn{}
        |> Plug.Conn.put_req_header("x-telegram-bot-api-secret-token", "conn-secret")

      assert Webhook.verify_secret_token(conn, "conn-secret") == true
      assert Webhook.verify_secret_token(conn, "wrong-secret") == false
    end

    test "returns false when Plug.Conn does not have secret token header" do
      conn = %Plug.Conn{}
      assert Webhook.verify_secret_token(conn, "secret") == false
    end

    test "returns false for invalid inputs" do
      assert Webhook.verify_secret_token(nil, "secret") == false
      assert Webhook.verify_secret_token("token", nil) == false
    end
  end
end
