defmodule Lux.Prisms.Telegram.Messages.AnalyzeContentTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Messages.AnalyzeContent

  @agent_ctx %{name: "TestAgent"}

  describe "handler/2 — content analysis" do
    test "detects bot commands" do
      assert {:ok, result} = AnalyzeContent.handler(%{text: "/start hello world"}, @agent_ctx)
      assert result.type == "command"
      assert result.command == "/start"
    end

    test "detects @mentions" do
      assert {:ok, result} = AnalyzeContent.handler(%{text: "Hello @alice and @bob"}, @agent_ctx)
      assert result.type == "mention"
      assert "@alice" in result.mentions
      assert "@bob" in result.mentions
    end

    test "detects #hashtags" do
      assert {:ok, result} = AnalyzeContent.handler(%{text: "#Elixir is awesome #programming"}, @agent_ctx)
      assert result.type == "hashtag"
      assert "#Elixir" in result.hashtags
      assert "#programming" in result.hashtags
    end

    test "detects URLs" do
      assert {:ok, result} = AnalyzeContent.handler(%{text: "Check https://example.com for more"}, @agent_ctx)
      assert result.type == "url"
      assert "https://example.com" in result.urls
    end

    test "detects email addresses" do
      assert {:ok, result} = AnalyzeContent.handler(%{text: "Email us at info@example.com"}, @agent_ctx)
      assert "info@example.com" in result.emails
    end

    test "classifies plain text" do
      assert {:ok, result} = AnalyzeContent.handler(%{text: "Just a plain message"}, @agent_ctx)
      assert result.type == "text"
      assert result.command == nil
      assert result.mentions == []
      assert result.urls == []
      assert result.hashtags == []
    end

    test "counts words correctly" do
      assert {:ok, result} = AnalyzeContent.handler(%{text: "one two three four"}, @agent_ctx)
      assert result.word_count == 4
    end

    test "counts characters correctly" do
      assert {:ok, result} = AnalyzeContent.handler(%{text: "hello"}, @agent_ctx)
      assert result.char_count == 5
    end

    test "detects formatting markers" do
      assert {:ok, result} = AnalyzeContent.handler(%{text: "*bold* text"}, @agent_ctx)
      assert result.has_formatting == true
    end

    test "no formatting in plain text" do
      assert {:ok, result} = AnalyzeContent.handler(%{text: "plain text here"}, @agent_ctx)
      assert result.has_formatting == false
    end

    test "command takes precedence over mentions" do
      assert {:ok, result} = AnalyzeContent.handler(%{text: "/cmd @user"}, @agent_ctx)
      assert result.type == "command"
      assert "@user" in result.mentions
    end

    test "accepts string keys in params" do
      assert {:ok, result} = AnalyzeContent.handler(%{"text" => "/help"}, @agent_ctx)
      assert result.command == "/help"
    end

    test "handles empty text" do
      assert {:ok, result} = AnalyzeContent.handler(%{text: ""}, @agent_ctx)
      assert result.type == "text"
      assert result.word_count == 0
      assert result.char_count == 0
    end
  end
end
