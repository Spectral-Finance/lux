defmodule Lux.Lenses.Perplexity.SearchTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Perplexity.Search

  describe "before_focus/1" do
    test "transforms query to messages format" do
      params = %{query: "What is Elixir?", model: "sonar-pro"}
      result = Search.before_focus(params)

      assert result.model == "sonar-pro"
      assert length(result.messages) == 1
      assert hd(result.messages).content == "What is Elixir?"
    end

    test "uses default model if not provided" do
      params = %{query: "What is Elixir?"}
      result = Search.before_focus(params)

      assert result.model == "sonar-pro"
    end
  end

  describe "after_focus/1" do
    test "extracts citations and answer" do
      response = %{
        "id" => "cmpl-123",
        "choices" => [
          %{
            "message" => %{"role" => "assistant", "content" => "Elixir is a functional language [1]."}
          }
        ],
        "citations" => ["https://elixir-lang.org/"],
        "usage" => %{"total_tokens" => 20}
      }

      assert {:ok, result} = Search.after_focus(response)
      
      assert result.answer == "Elixir is a functional language [1]."
      assert result.citations == ["https://elixir-lang.org/"]
      assert result.usage["total_tokens"] == 20
    end
  end
end
