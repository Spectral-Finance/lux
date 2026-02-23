defmodule Lux.Prisms.Telegram.Messages.GenerateDeepLinkTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Messages.GenerateDeepLink

  @agent_ctx %{name: "TestAgent"}

  describe "handler/2 — generating deep links" do
    test "generates a private chat deep link" do
      assert {:ok, %{url: url, type: "private", payload: "ref_abc123"}} =
               GenerateDeepLink.handler(%{bot_username: "mybot", payload: "ref_abc123"}, @agent_ctx)
      assert url == "https://t.me/mybot?start=ref_abc123"
    end

    test "generates a group invite deep link" do
      assert {:ok, %{url: url, type: "group"}} =
               GenerateDeepLink.handler(%{bot_username: "mybot", payload: "invite", type: "group"}, @agent_ctx)
      assert url == "https://t.me/mybot?startgroup=invite"
    end

    test "generates a channel invite deep link" do
      assert {:ok, %{url: url, type: "channel"}} =
               GenerateDeepLink.handler(%{bot_username: "mybot", payload: "sub", type: "channel"}, @agent_ctx)
      assert url == "https://t.me/mybot?startchannel=sub"
    end

    test "strips @ prefix from bot_username" do
      assert {:ok, %{url: url}} =
               GenerateDeepLink.handler(%{bot_username: "@cleanbot", payload: "x"}, @agent_ctx)
      assert url =~ "t.me/cleanbot"
    end

    test "handles empty payload" do
      assert {:ok, %{url: url}} =
               GenerateDeepLink.handler(%{bot_username: "mybot", payload: ""}, @agent_ctx)
      assert url == "https://t.me/mybot?start="
    end

    test "returns error for missing bot_username" do
      assert {:error, msg} = GenerateDeepLink.handler(%{payload: "test"}, @agent_ctx)
      assert msg =~ "bot_username"
    end

    test "returns error for payload over 64 chars" do
      long_payload = String.duplicate("x", 65)
      assert {:error, msg} = GenerateDeepLink.handler(%{bot_username: "mybot", payload: long_payload}, @agent_ctx)
      assert msg =~ "too long"
    end
  end

  describe "handler/2 — parsing deep links" do
    test "parses a private chat deep link" do
      assert {:ok, %{bot_username: "mybot", payload: "ref_abc", type: "private"}} =
               GenerateDeepLink.handler(%{parse: "https://t.me/mybot?start=ref_abc"}, @agent_ctx)
    end

    test "parses a group deep link" do
      assert {:ok, %{bot_username: "mybot", payload: "invite", type: "group"}} =
               GenerateDeepLink.handler(%{parse: "https://t.me/mybot?startgroup=invite"}, @agent_ctx)
    end

    test "parses a channel deep link" do
      assert {:ok, %{bot_username: "mybot", payload: "sub", type: "channel"}} =
               GenerateDeepLink.handler(%{parse: "https://t.me/mybot?startchannel=sub"}, @agent_ctx)
    end

    test "returns error for invalid URL" do
      assert {:error, msg} = GenerateDeepLink.handler(%{parse: "https://not-telegram.com/link"}, @agent_ctx)
      assert msg =~ "Invalid"
    end

    test "accepts string keys" do
      assert {:ok, %{url: _}} =
               GenerateDeepLink.handler(%{"bot_username" => "mybot", "payload" => "test"}, @agent_ctx)
    end
  end
end
