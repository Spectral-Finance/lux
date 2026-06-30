defmodule Lux.Integrations.Telegram.CommandParserTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.CommandParser

  describe "parse/1" do
    test "correctly parses basic commands" do
      assert {:ok, res} = CommandParser.parse("/start")
      assert res.command == "start"
      assert res.args == []

      assert {:ok, res2} = CommandParser.parse("/help arg1 arg2")
      assert res2.command == "help"
      assert res2.args == ["arg1", "arg2"]
    end

    test "strips bot username suffix" do
      assert {:ok, res} = CommandParser.parse("/start@MyAwesomeBot payload")
      assert res.command == "start"
      assert res.args == ["payload"]
    end

    test "parses flags correctly and separates positional args" do
      assert {:ok, res} = CommandParser.parse("/add --item apple --qty 5 positional1 positional2")
      assert res.command == "add"
      assert res.flags == %{"item" => "apple", "qty" => "5"}
      assert res.args == ["positional1", "positional2"]
    end

    test "handles boolean flags" do
      assert {:ok, res} = CommandParser.parse("/cmd --force --verbose file.txt")
      assert res.command == "cmd"
      assert res.flags == %{"force" => "true", "verbose" => "true"}
      assert res.args == ["file.txt"]
    end

    test "handles --key=value style flags" do
      assert {:ok, res} = CommandParser.parse("/cmd --key1=value1 -k2=v2")
      assert res.command == "cmd"
      assert res.flags == %{"key1" => "value1", "k2" => "v2"}
      assert res.args == []
    end

    test "handles quoted arguments" do
      assert {:ok, res} = CommandParser.parse("/msg \"hello world\" --to \"John Doe\"")
      assert res.command == "msg"
      assert res.flags == %{"to" => "John Doe"}
      assert res.args == ["hello world"]
    end

    test "handles malformed flags gracefully" do
      assert {:ok, res} = CommandParser.parse("/cmd - -- --extra")
      assert res.command == "cmd"
      assert res.flags == %{}
      assert res.args == ["-", "--extra"]
    end

    test "handles non-commands gracefully" do
      assert {:error, :not_a_command} = CommandParser.parse("hello bot")
      assert {:error, :not_a_command} = CommandParser.parse("")
    end
  end

  describe "extract_deep_link/1" do
    test "extracts payload from start command" do
      assert {:ok, "my_invite_code"} = CommandParser.extract_deep_link("/start my_invite_code")
    end

    test "returns error on missing payload or other command" do
      assert {:error, :no_deep_link} = CommandParser.extract_deep_link("/start")
      assert {:error, :no_deep_link} = CommandParser.extract_deep_link("/help payload")
    end
  end
end
