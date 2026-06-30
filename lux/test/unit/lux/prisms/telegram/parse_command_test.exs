defmodule Lux.Prisms.Telegram.ParseCommandTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Telegram.ParseCommand

  test "parses a telegram command via prism" do
    assert {:ok, result} = ParseCommand.run(%{"text" => "/start --mode advanced"})
    assert result.command == "start"
    assert result.flags == %{"mode" => "advanced"}
  end

  test "returns error for non-commands" do
    assert {:error, :not_a_command} = ParseCommand.run(%{"text" => "hello"})
  end
end
