defmodule Lux.Prisms.Telegram.CommandRouterTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Telegram.CommandRouter

  test "parses simple command" do
    {:ok, result} = CommandRouter.parse_command("/start")
    assert result.command == "/start"
    assert result.args == []
    assert result.is_command == true
  end

  test "parses command with bot username" do
    {:ok, result} = CommandRouter.parse_command("/help@mybot")
    assert result.command == "/help"
    assert result.bot == "mybot"
  end

  test "filters by bot username" do
    assert :not_a_command = CommandRouter.parse_command("/help@otherbot", "mybot")
    {:ok, result} = CommandRouter.parse_command("/help@mybot", "mybot")
    assert result.command == "/help"
  end

  test "parses positional args" do
    {:ok, result} = CommandRouter.parse_command("/ban user123 24h")
    assert result.command == "/ban"
    assert result.args == ["user123", "24h"]
  end

  test "parses named params" do
    {:ok, result} = CommandRouter.parse_command("/config lang=en theme=dark")
    assert result.command == "/config"
    assert result.params["lang"] == "en"
    assert result.params["theme"] == "dark"
  end

  test "parses mixed args and params" do
    {:ok, result} = CommandRouter.parse_command("/search hello lang=en")
    assert result.args == ["hello"]
    assert result.params["lang"] == "en"
  end

  test "deep link decoding for /start" do
    encoded = Base.url_encode64("welcome_ref-abc", padding: false)
    {:ok, result} = CommandRouter.parse_command("/start #{encoded}")
    assert result.deep_link != nil
    assert result.deep_link.decoded == "welcome_ref-abc"
  end

  test "not a command" do
    assert :not_a_command = CommandRouter.parse_command("hello world")
  end

  test "handler returns is_command false for non-commands" do
    {:ok, result} = CommandRouter.handler(%{text: "just text"}, nil)
    assert result.is_command == false
    assert result.command == nil
  end
end
