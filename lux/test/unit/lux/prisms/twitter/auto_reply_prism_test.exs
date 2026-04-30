defmodule Lux.Prisms.Twitter.AutoReplyPrismTest do
  use ExUnit.Case, async: true
  doctest Lux.Prisms.Twitter.AutoReplyPrism

  describe "run/1" do
    test "generates reply for question" do
      assert {:ok, result} = Lux.Prisms.Twitter.AutoReplyPrism.run(%{
        tweet_id: "12345",
        text: "What do you think about DeFi?",
        author_id: "67890"
      })

      assert result[:reply] != ""
      assert result[:action] == "reply"
      assert result[:should_reply] == true
      assert result[:trigger_rule] != nil
    end

    test "generates complaint reply for negative sentiment" do
      {:ok, result} = Lux.Prisms.Twitter.AutoReplyPrism.run(%{
        tweet_id: "12345",
        text: "This is terrible and awful service!",
        author_id: "67890",
        sentiment: "negative"
      })

      assert result[:reply] != ""
      assert result[:escalation_required] == true
      assert result[:trigger_rule] == "negative_sentiment"
    end

    test "generates positive reply for positive sentiment" do
      {:ok, result} = Lux.Prisms.Twitter.AutoReplyPrism.run(%{
        tweet_id: "12345",
        text: "Great work on the new feature! Love it!",
        author_id: "67890",
        sentiment: "positive"
      })

      assert result[:reply] != ""
      assert result[:trigger_rule] == "positive_sentiment"
      assert result[:escalation_required] == false
    end

    test "does not reply when auto_reply is disabled" do
      {:ok, result} = Lux.Prisms.Twitter.AutoReplyPrism.run(%{
        tweet_id: "12345",
        text: "Hello!",
        author_id: "67890",
        auto_reply_enabled: false
      })

      assert result[:reply] == ""
      assert result[:action] == "none"
      assert result[:should_reply] == false
    end

    test "respects max_reply_length" do
      long_text = String.duplicate("a", 500)

      {:ok, result} = Lux.Prisms.Twitter.AutoReplyPrism.run(%{
        tweet_id: "12345",
        text: long_text,
        author_id: "67890",
        max_reply_length: 50
      })

      assert String.length(result[:reply]) <= 50
    end

    test "detects keyword triggers" do
      {:ok, result} = Lux.Prisms.Twitter.AutoReplyPrism.run(%{
        tweet_id: "12345",
        text: "What is the current price of the token?",
        author_id: "67890"
      })

      assert result[:trigger_rule] == "price_trigger"
    end

    test "confidence is between 0 and 1" do
      {:ok, result} = Lux.Prisms.Twitter.AutoReplyPrism.run(%{
        tweet_id: "12345",
        text: "What is the price?",
        author_id: "67890"
      })

      assert result[:confidence] >= 0.0
      assert result[:confidence] <= 1.0
    end

    test "has correct prism metadata" do
      assert Lux.Prisms.Twitter.AutoReplyPrism.__meta__(:name) == "Auto Reply Manager"
    end

    test "input schema has required fields" do
      schema = Lux.Prisms.Twitter.AutoReplyPrism.__input_schema__()
      assert "tweet_id" in schema[:required]
      assert "text" in schema[:required]
      assert "author_id" in schema[:required]
    end

    test "generates generic reply for unmatched content" do
      {:ok, result} = Lux.Prisms.Twitter.AutoReplyPrism.run(%{
        tweet_id: "12345",
        text: "Random message with no special keywords",
        author_id: "67890"
      })

      assert result[:reply] != ""
      assert result[:should_reply] == true
      assert result[:trigger_rule] == "default"
    end
  end
end
