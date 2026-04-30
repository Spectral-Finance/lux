defmodule Lux.Prisms.Twitter.AutoReplyPrism do
  @moduledoc """
  A prism that manages intelligent auto-replies to Twitter mentions and DMs.

  Analyzes incoming tweets and DMs to generate contextually appropriate
  auto-replies based on configurable rules, sentiment analysis, and
  conversation history. Supports reply templates, keyword triggers,
  and escalation rules.

  ## Examples

      iex> Lux.Prisms.Twitter.AutoReplyPrism.run(%{
      ...>   tweet_id: "12345",
      ...>   text: "What do you think about DeFi?",
      ...>   author_id: "67890"
      ...> })
      {:ok, %{reply: "...", action: "reply"}}
  """

  use Lux.Prism,
    name: "Auto Reply Manager",
    description: "Manages intelligent auto-replies to Twitter mentions and DMs with configurable rules and templates",
    input_schema: %{
      type: :object,
      properties: %{
        tweet_id: %{
          type: :string,
          description: "ID of the tweet to reply to"
        },
        text: %{
          type: :string,
          description: "Text content of the incoming tweet or DM"
        },
        author_id: %{
          type: :string,
          description: "Twitter user ID of the author"
        },
        message_type: %{
          type: :string,
          description: "Type of message",
          enum: ["mention", "reply", "dm", "quote"],
          default: "mention"
        },
        sentiment: %{
          type: :string,
          description: "Detected sentiment of the message",
          enum: ["positive", "neutral", "negative", "unknown"]
        },
        keywords: %{
          type: :array,
          items: %{type: :string},
          description: "Keywords detected in the message"
        },
        conversation_history: %{
          type: :array,
          items: %{type: :object},
          description: "Previous messages in the conversation"
        },
        auto_reply_enabled: %{
          type: :boolean,
          description: "Whether auto-replies are enabled",
          default: true
        },
        max_reply_length: %{
          type: :integer,
          description: "Maximum length of auto-reply",
          default: 280
        }
      },
      required: ["tweet_id", "text", "author_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        reply: %{type: :string},
        action: %{type: :string},
        confidence: %{type: :number},
        trigger_rule: %{type: :string},
        should_reply: %{type: :boolean},
        reply_template: %{type: :string},
        escalation_required: %{type: :boolean}
      }
    }

  @doc """
  Generates an intelligent auto-reply based on the incoming message.
  """
  def run(params) do
    tweet_id = Map.get(params, :tweet_id, params["tweet_id"])
    text = Map.get(params, :text, params["text"])
    author_id = Map.get(params, :author_id, params["author_id"])
    message_type = Map.get(params, :message_type, params["message_type"] || "mention")
    sentiment = Map.get(params, :sentiment, params["sentiment"] || detect_sentiment(text))
    keywords = Map.get(params, :keywords, params["keywords"] || extract_keywords(text))
    conversation_history = Map.get(params, :conversation_history, params["conversation_history"] || [])
    auto_reply_enabled = Map.get(params, :auto_reply_enabled, params["auto_reply_enabled"] || true)
    max_reply_length = Map.get(params, :max_reply_length, params["max_reply_length"] || 280)

    # Check if auto-reply is enabled
    unless auto_reply_enabled do
      {:ok, %{
        reply: "",
        action: "none",
        confidence: 0.0,
        trigger_rule: nil,
        should_reply: false,
        reply_template: nil,
        escalation_required: false
      }}
    else
      # Determine the appropriate action
      {reply, action, trigger_rule, template, escalation_required} =
        determine_response(%{
          text: text,
          message_type: message_type,
          sentiment: sentiment,
          keywords: keywords,
          conversation_history: conversation_history,
          author_id: author_id
        })

      # Ensure reply length is within limits
      reply = if reply, do: String.slice(reply, 0, max_reply_length), else: ""

      # Calculate confidence
      confidence = calculate_confidence(reply, trigger_rule, sentiment)

      result = %{
        reply: reply,
        action: action,
        confidence: confidence,
        trigger_rule: trigger_rule,
        should_reply: reply != "" and action != "none",
        reply_template: template,
        escalation_required: escalation_required
      }

      {:ok, result}
    end
  end

  defp determine_response(params) do
    %{
      text: text,
      message_type: message_type,
      sentiment: sentiment,
      keywords: keywords,
      conversation_history: conversation_history
    } = params

    text_lower = String.downcase(text)

    cond do
      String.ends_with?(text, "?") or String.contains?(text_lower, ["what ", "how ", "why ", "when ", "where ", "who ", "is ", "are ", "can ", "do "]) ->
        {generate_question_reply(text, keywords), "reply", "question_detected", "question_template", false}
      sentiment == "negative" or String.contains?(text_lower, ["hate", "awful", "terrible", "scam", "fraud", "worst"]) ->
        {generate_complaint_reply(text), "reply", "negative_sentiment", "complaint_template", true}
      sentiment == "positive" or String.contains?(text_lower, ["love", "great", "amazing", "awesome", "thanks", "thank"]) ->
        {generate_positive_reply(text), "reply", "positive_sentiment", "positive_template", false}
      true ->
        case check_keyword_triggers(text_lower, keywords) do
          {reply, rule, template, escalation} when reply != nil ->
            {reply, "reply", rule, template, escalation}
          nil ->
            {generate_generic_reply(text), "reply", "default", "generic_template", false}
        end
    end
  end

  defp generate_question_reply(text, keywords) do
    cond do
      Enum.any?(keywords, &(&1 in ["price", "token", "defi", "yield"])) ->
        "Thanks for your question about #{Enum.join(keywords, ", ")}! Our team is working on comprehensive analysis. Stay tuned for updates! 📊"
      Enum.any?(keywords, &(&1 in ["bug", "error", "issue"])) ->
        "We appreciate you bringing this to our attention. Our team will investigate and get back to you shortly. 🔧"
      true ->
        "Great question! We're analyzing this and will share our insights soon. Follow us for the latest updates! 🔍"
    end
  end

  defp generate_complaint_reply(text) do
    "We're sorry to hear that. Please DM us with more details so our team can assist you directly. We value your feedback and are committed to improving! 🙏"
  end

  defp generate_positive_reply(text) do
    "Thank you for the kind words! We're glad you're enjoying our content. Don't forget to follow for more updates! 🚀"
  end

  defp check_keyword_triggers(text_lower, keywords) do
    triggers = [
      {"price", "Our latest price analysis is available at [link]. We update this regularly! 📈", "price_trigger", "price_template", false},
      {"airdrop", "Stay tuned for upcoming airdrop announcements! Follow and enable notifications. 🎁", "airdrop_trigger", "airdrop_template", false},
      {"help", "How can we help? Please provide more details about your question. 💬", "help_trigger", "help_template", false},
      {"partnership", "We're always open to exciting partnerships! Please DM us with your proposal. 🤝", "partnership_trigger", "partnership_template", true},
      {"bug", "Thanks for reporting! Our dev team will look into this. Please DM us with steps to reproduce. 🐛", "bug_trigger", "bug_template", false}
    ]

    Enum.find_value(triggers, fn {keyword, reply, rule, template, escalation} ->
      if String.contains?(text_lower, keyword) do
        {reply, rule, template, escalation}
      else
        nil
      end
    end)
  end

  defp generate_generic_reply(text) do
    "Thanks for reaching out! We appreciate your engagement with our community. 🙌"
  end

  defp detect_sentiment(text) do
    text_lower = String.downcase(text)

    positive_words = ["love", "great", "amazing", "awesome", "excellent", "fantastic", "wonderful", "thanks", "thank", "good", "best"]
    negative_words = ["hate", "awful", "terrible", "horrible", "worst", "bad", "scam", "fraud", "disappointed", "angry"]

    positive_count = Enum.count(positive_words, &String.contains?(text_lower, &1))
    negative_count = Enum.count(negative_words, &String.contains?(text_lower, &1))

    cond do
      positive_count > negative_count -> "positive"
      negative_count > positive_count -> "negative"
      true -> "neutral"
    end
  end

  defp extract_keywords(text) do
    # Simple keyword extraction - look for common crypto/tech terms
    common_keywords = [
      "price", "token", "defi", "yield", "airdrop", "nft", "web3", "blockchain",
      "ethereum", "solana", "polygon", "staking", "liquidity", "governance",
      "bug", "error", "issue", "help", "partnership", "collab"
    ]

    text_lower = String.downcase(text)
    Enum.filter(common_keywords, &String.contains?(text_lower, &1))
  end

  defp calculate_confidence(reply, trigger_rule, sentiment) do
    base_confidence = 0.5

    # Boost confidence for specific trigger rules
    rule_boost = case trigger_rule do
      "question_detected" -> 0.2
      "negative_sentiment" -> 0.15
      "positive_sentiment" -> 0.15
      rule when rule != nil and String.ends_with?(rule, "_trigger") -> 0.25
      _ -> 0.0
    end

    # Boost confidence for known sentiment
    sentiment_boost = case sentiment do
      "positive" -> 0.1
      "negative" -> 0.1
      _ -> 0.0
    end

    # Reply presence boost
    reply_boost = if reply != nil and reply != "", do: 0.1, else: 0.0

    confidence = base_confidence + rule_boost + sentiment_boost + reply_boost
    |> min(1.0)
    |> Float.round(2)

    confidence
  end
end
