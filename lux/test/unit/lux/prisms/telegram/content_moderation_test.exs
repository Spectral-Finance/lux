defmodule Lux.Prisms.Telegram.ContentModerationTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Telegram.ContentModeration

  setup do
    Req.Test.stub(Lux.Telegram.DeleteMock, fn conn ->
      Req.Test.json(conn, %{"ok" => true, "result" => true})
    end)
    :ok
  end

  test "detects spam text" do
    assert {:ok, %{result: %{is_spam: true, spam_score: score}}} =
      ContentModeration.handler(%{action: "check_spam", text: "Earn $5000 per day! Click here link http://scam.com"}, nil)
    assert score >= 30
  end

  test "clean text is not spam" do
    assert {:ok, %{result: %{is_spam: false, spam_score: 0}}} =
      ContentModeration.handler(%{action: "check_spam", text: "Hello, how is everyone doing today?"}, nil)
  end

  test "detects excessive caps" do
    assert {:ok, %{result: %{excessive_caps: true}}} =
      ContentModeration.handler(%{action: "check_spam", text: "THIS IS ALL CAPS AND VERY ANNOYING STUFF HERE"}, nil)
  end

  test "check_content with forbidden words" do
    assert {:ok, %{result: %{compliant: false, violations: [:forbidden_words], forbidden_words_found: ["badword"]}}} =
      ContentModeration.handler(%{
        action: "check_content",
        text: "This contains a badword in it",
        rules: %{forbidden_words: ["badword", "offensive"]}
      }, nil)
  end

  test "check_content with no_links rule" do
    assert {:ok, %{result: %{compliant: false, violations: [:contains_links]}}} =
      ContentModeration.handler(%{
        action: "check_content",
        text: "Check out https://example.com",
        rules: %{no_links: true}
      }, nil)
  end

  test "check_content with max_length rule" do
    assert {:ok, %{result: %{compliant: false, violations: [:too_long]}}} =
      ContentModeration.handler(%{
        action: "check_content",
        text: String.duplicate("a", 200),
        rules: %{max_length: 100}
      }, nil)
  end

  test "compliant content passes all rules" do
    assert {:ok, %{result: %{compliant: true, violations: []}}} =
      ContentModeration.handler(%{
        action: "check_content",
        text: "Normal clean message",
        rules: %{max_length: 500, no_links: true, forbidden_words: ["spam"]}
      }, nil)
  end

  test "delete_message" do
    assert {:ok, %{result: true, action: "delete_message"}} =
      ContentModeration.handler(%{
        action: "delete_message", chat_id: -100123, message_id: 42,
        token: "t", plug: {Req.Test, Lux.Telegram.DeleteMock}
      }, nil)
  end

  test "delete_messages bulk" do
    assert {:ok, %{result: true, action: "delete_messages"}} =
      ContentModeration.handler(%{
        action: "delete_messages", chat_id: -100123, message_ids: [1, 2, 3],
        token: "t", plug: {Req.Test, Lux.Telegram.DeleteMock}
      }, nil)
  end

  test "auto_moderate spam triggers ban recommendation" do
    assert {:ok, %{result: %{should_act: true, severity: severity}}} =
      ContentModeration.handler(%{
        action: "auto_moderate",
        text: "FREE MONEY! Earn $1000 per day! Click here link! 100% guaranteed profit!",
        rules: %{}
      }, nil)
    assert severity in [:ban, :restrict]
  end

  test "auto_moderate clean text recommends no action" do
    assert {:ok, %{result: %{should_act: false, severity: :none}}} =
      ContentModeration.handler(%{
        action: "auto_moderate",
        text: "Good morning everyone!",
        rules: %{}
      }, nil)
  end
end
