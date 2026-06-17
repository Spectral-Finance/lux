defmodule Lux.Lenses.Telegram.Bot.GetMeTest do
  use ExUnit.Case, async: true
  alias Lux.Lenses.Telegram.Bot.GetMe

  describe "after_focus/1" do
    test "returns ok tuple on success" do
      response = %{
        "ok" => true,
        "result" => %{
          "id" => 123456,
          "is_bot" => true,
          "first_name" => "TestBot",
          "username" => "test_bot"
        }
      }

      assert {:ok, result} = GetMe.after_focus(response)
      assert result["username"] == "test_bot"
    end

    test "returns error tuple on failure" do
      response = %{
        "ok" => false,
        "error_code" => 401,
        "description" => "Unauthorized"
      }

      assert {:error, "Unauthorized"} = GetMe.after_focus(response)
    end
  end
end
