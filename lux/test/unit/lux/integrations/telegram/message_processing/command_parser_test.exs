defmodule Lux.Integrations.Telegram.MessageProcessing.CommandParserTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.MessageProcessing.CommandParser

  describe "is_command?/2" do
    test "identifies commands with default prefix" do
      assert CommandParser.is_command?("/start")
      assert CommandParser.is_command?("   /help")
      assert CommandParser.is_command?("/price@LuxBot BTC")
      refute CommandParser.is_command?("Hello world")
      refute CommandParser.is_command?(nil)
    end

    test "supports custom prefixes" do
      assert CommandParser.is_command?("!ping", "!")
      refute CommandParser.is_command?("/ping", "!")
    end
  end

  describe "parse/2" do
    test "parses simple command without arguments" do
      assert {:ok, result} = CommandParser.parse("/start")
      assert result.is_command == true
      assert result.command == "start"
      assert result.args == []
      assert result.options == %{}
      assert result.target_bot == nil
    end

    test "parses command with bot username mention" do
      assert {:ok, result} = CommandParser.parse("/help@LuxBot")
      assert result.command == "help"
      assert result.target_bot == "LuxBot"
    end

    test "filters out command if targeted at different bot" do
      assert {:ignored, "OtherBot"} =
               CommandParser.parse("/start@OtherBot", bot_username: "LuxBot")

      assert {:ok, result} =
               CommandParser.parse("/start@LuxBot", bot_username: "luxbot")

      assert result.command == "start"
    end

    test "parses positional arguments with quotes" do
      text = ~s(/announce "System Maintenance" "We will be offline for 1 hour" urgent)
      assert {:ok, result} = CommandParser.parse(text)
      assert result.command == "announce"

      assert result.args == [
               "System Maintenance",
               "We will be offline for 1 hour",
               "urgent"
             ]
    end

    test "parses GNU-style flags and options" do
      text = "/trade buy 100 ETH --slippage=0.5 --dry-run --env prod -v"
      assert {:ok, result} = CommandParser.parse(text)
      assert result.command == "trade"
      assert result.args == ["buy", 100, "ETH"]
      assert result.options.slippage == 0.5
      assert result.options.dry_run == true
      assert result.options.env == "prod"
      assert result.options.v == true
    end

    test "returns is_command: false for regular chat text" do
      assert {:ok, %{is_command: false}} = CommandParser.parse("Good morning agents!")
    end

    test "extract_command_name/2 helper" do
      assert CommandParser.extract_command_name("/SWAP eth usdc") == "swap"
      assert CommandParser.extract_command_name("hello") == nil
    end

    test "validate_spec/2 validates required arguments" do
      {:ok, cmd} = CommandParser.parse("/transfer 100")

      spec = %{required_args: [:amount, :recipient]}
      assert {:error, "Missing required argument: recipient"} =
               CommandParser.validate_spec(cmd, spec)

      {:ok, valid_cmd} = CommandParser.parse("/transfer 100 0x123")
      assert {:ok, _} = CommandParser.validate_spec(valid_cmd, spec)
    end
  end
end
