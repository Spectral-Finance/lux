defmodule Lux.Prisms.Telegram.Messages.ParseCommandTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Messages.ParseCommand

  @agent_ctx %{name: "TestAgent"}

  describe "handler/2 — command parsing" do
    test "parses a simple command with no arguments" do
      assert {:ok, result} = ParseCommand.handler(%{text: "/start"}, @agent_ctx)
      assert result.command == "start"
      assert result.bot_target == nil
      assert result.args == []
      assert result.raw == "/start"
    end

    test "parses a command with a bot target" do
      assert {:ok, result} = ParseCommand.handler(%{text: "/help@mybot"}, @agent_ctx)
      assert result.command == "help"
      assert result.bot_target == "mybot"
      assert result.args == []
    end

    test "parses a command with arguments" do
      assert {:ok, result} = ParseCommand.handler(%{text: "/ban user123 reason here"}, @agent_ctx)
      assert result.command == "ban"
      assert result.args == ["user123", "reason", "here"]
    end

    test "parses a command with bot target and arguments" do
      assert {:ok, result} = ParseCommand.handler(%{text: "/settings@configbot option value"}, @agent_ctx)
      assert result.command == "settings"
      assert result.bot_target == "configbot"
      assert result.args == ["option", "value"]
    end

    test "normalizes command to lowercase" do
      assert {:ok, result} = ParseCommand.handler(%{text: "/START"}, @agent_ctx)
      assert result.command == "start"
    end

    test "handles commands with underscores" do
      assert {:ok, result} = ParseCommand.handler(%{text: "/my_command arg1"}, @agent_ctx)
      assert result.command == "my_command"
      assert result.args == ["arg1"]
    end

    test "returns error for non-command text" do
      assert {:error, msg} = ParseCommand.handler(%{text: "Hello, not a command"}, @agent_ctx)
      assert msg =~ "does not start with"
    end

    test "returns error for empty text" do
      assert {:error, _msg} = ParseCommand.handler(%{text: ""}, @agent_ctx)
    end

    test "accepts string keys in params" do
      assert {:ok, result} = ParseCommand.handler(%{"text" => "/start hello"}, @agent_ctx)
      assert result.command == "start"
      assert result.args == ["hello"]
    end

    test "handles commands with multiple spaces between args" do
      assert {:ok, result} = ParseCommand.handler(%{text: "/cmd  arg1   arg2"}, @agent_ctx)
      assert result.args == ["arg1", "arg2"]
    end
  end
end
