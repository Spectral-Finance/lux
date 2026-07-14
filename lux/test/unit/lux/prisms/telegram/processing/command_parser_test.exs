defmodule Lux.Prisms.Telegram.Processing.CommandParserTest do
  use ExUnit.Case, async: true
  
  alias Lux.Prisms.Telegram.Processing.CommandParser

  describe "handler/2" do
    test "parses a basic command" do
      params = %{text: "/start"}
      assert {:ok, %{is_command: true, command: "start", args: []}} = CommandParser.handler(params, %{})
    end

    test "parses a command with arguments" do
      params = %{text: "/echo hello world"}
      assert {:ok, %{is_command: true, command: "echo", args: ["hello", "world"]}} = CommandParser.handler(params, %{})
    end

    test "parses a targeted command matching the bot username" do
      params = %{text: "/start@MyBot arg1", bot_username: "mybot"}
      assert {:ok, %{is_command: true, command: "start", args: ["arg1"]}} = CommandParser.handler(params, %{})
    end

    test "ignores targeted command for a different bot" do
      params = %{text: "/start@OtherBot", bot_username: "mybot"}
      assert {:ok, %{is_command: false}} = CommandParser.handler(params, %{})
    end

    test "returns false for normal text" do
      params = %{text: "hello world"}
      assert {:ok, %{is_command: false}} = CommandParser.handler(params, %{})
    end

    test "handles missing text" do
      params = %{}
      assert {:ok, %{is_command: false}} = CommandParser.handler(params, %{})
    end
    
    test "handles nil text" do
      params = %{text: nil}
      assert {:ok, %{is_command: false}} = CommandParser.handler(params, %{})
    end
  end
end
