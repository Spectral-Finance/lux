defmodule Lux.Lenses.Perplexity.ChatTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Perplexity.Chat

  describe "after_focus/1" do
    test "processes a successful chat response" do
      response = %{
        "id" => "cmpl-123",
        "choices" => [
          %{
            "message" => %{"role" => "assistant", "content" => "Hello!"},
            "finish_reason" => "stop"
          }
        ],
        "usage" => %{
          "prompt_tokens" => 10,
          "completion_tokens" => 5,
          "total_tokens" => 15
        }
      }

      assert {:ok, result} = Chat.after_focus(response)
      
      assert length(result.choices) == 1
      assert hd(result.choices).message["content"] == "Hello!"
      assert result.usage.total_tokens == 15
    end

    test "handles error response" do
      response = %{
        "error" => %{"message" => "Invalid token"}
      }

      assert {:error, "Invalid token"} = Chat.after_focus(response)
    end
  end
end
