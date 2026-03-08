defmodule Lux.Prisms.YouTube.Community.SpamDetectorTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.Community.SpamDetector

  test "clean comment" do
    result = SpamDetector.detect("Great video, learned a lot!")
    refute result.is_spam
    assert result.severity == :none
    assert result.recommended_action == :allow
  end

  test "sub4sub spam" do
    result = SpamDetector.detect("Sub4sub check my channel!")
    assert result.is_spam
    assert result.severity in [:high, :critical]
  end

  test "link spam" do
    result = SpamDetector.detect("Free iPhone at bit.ly/scam123")
    assert result.is_spam
    assert result.score >= 30
  end

  test "all caps spam" do
    result = SpamDetector.detect("SUBSCRIBE TO MY CHANNEL NOW!!!")
    assert result.score > 0
  end

  test "batch detect" do
    texts = ["Great video!", "Sub4sub check my channel", "Normal comment", "Click the link bit.ly/x"]
    result = SpamDetector.batch_detect(texts)
    assert result.total == 4
    assert result.spam_count >= 2
    assert result.spam_rate > 0
  end

  test "severity levels" do
    assert SpamDetector.detect("hi").severity == :none
    assert SpamDetector.detect("Sub4sub check my channel click here bit.ly/x").severity in [:critical, :high]
  end

  test "recommended actions" do
    clean = SpamDetector.detect("Nice video!")
    assert clean.recommended_action == :allow
    spam = SpamDetector.detect("Sub4sub free stuff at bit.ly/spam click here")
    assert spam.recommended_action in [:ban_and_delete, :delete]
  end
end
