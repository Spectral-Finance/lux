defmodule Lux.Prisms.YouTube.ClassifyComment do
  @moduledoc """
  A decision pipeline classification system that analyzes YouTube comments,
  detects sentiment, and classifies them into actionable states:
  - review: Needs manual community manager check.
  - reply: Positive or neutral query that can receive an automated response.
  - hide: Spammers, scam links, links-only, or abusive comments.
  - escalate: Technical issues, critical support requests, or system bugs.
  - no-action: Low engagement, short/irrelevant neutral inputs.
  """

  use Lux.Prism,
    name: "Classify YouTube Comment",
    description: "Analyzes and classifies YouTube comments into actionable states",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "Comment text to classify"},
        author_display_name: %{type: :string, description: "Author displayName"}
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        state: %{
          type: :string,
          enum: ["review", "reply", "hide", "escalate", "no-action"],
          description: "Action state"
        },
        sentiment: %{
          type: :string,
          enum: ["positive", "negative", "neutral"],
          description: "Detected sentiment"
        },
        confidence: %{type: :number, description: "Classification confidence"},
        recommended_reply: %{type: :string, description: "Automated reply text (optional)"},
        reasons: %{
          type: :array,
          items: %{type: :string},
          description: "Reasons for the classification"
        }
      },
      required: ["state", "sentiment", "confidence", "reasons"]
    }

  @doc """
  Analyzes a comment and classifies it into a state.
  """
  def handler(params, _agent) do
    params = Lux.Integrations.YouTube.Utils.normalize_to_atoms(params)
    text = Map.get(params, :text, "")
    _author = Map.get(params, :author_display_name, "User")

    downcased = String.downcase(text)

    # 1. Check for URL
    has_url = String.contains?(downcased, "http://") or String.contains?(downcased, "https://") or Regex.run(~r/\b[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(:[0-9]{1,5})?(\/.*)?\b/i, text) != nil

    # 2. Check for scam keywords
    scam_keywords = ["whatsapp", "telegram", "contact", "whatsapp me", "telegram me", "crypto profit", "easy money", "guaranteed return", "investment help", "invest", "giveaway", "whatsapp:", "telegram:", "dm me", "click here", "cash back", "make money"]
    is_scam_link = Enum.any?(scam_keywords, &String.contains?(downcased, &1))

    # 3. Check for links-only spam
    # Just a URL with very few other words
    is_links_only = has_url and (String.length(String.replace(text, ~r/https?:\/\/\S+/i, "")) < 15)

    # 4. Check for escalation keywords
    escalate_keywords = ["broken", "bug", "crash", "error", "hack", "stolen", "loss", "lost", "fail", "not working", "cannot login", "failed", "billing", "support", "help desk"]
    is_escalate = Enum.any?(escalate_keywords, &String.contains?(downcased, &1))

    # 5. Check for vulgar/abusive words
    abusive_keywords = ["fuck", "shit", "bastard", "scumbag", "idiot", "asshole", "bitch"]
    is_abusive = Enum.any?(abusive_keywords, &String.contains?(downcased, &1))

    # 6. Analyze sentiment
    {sentiment, sentiment_confidence} = get_sentiment(text)

    # 7. Apply decision rules
    cond do
      is_scam_link ->
        {:ok, %{
          state: "hide",
          sentiment: "negative",
          confidence: 0.95,
          reasons: ["scam links / financial spam detected"],
          recommended_reply: nil
        }}

      is_links_only ->
        {:ok, %{
          state: "hide",
          sentiment: "neutral",
          confidence: 0.95,
          reasons: ["links-only spam detected"],
          recommended_reply: nil
        }}

      is_abusive ->
        {:ok, %{
          state: "hide",
          sentiment: "negative",
          confidence: 0.9,
          reasons: ["abusive / vulgar content detected"],
          recommended_reply: nil
        }}

      is_escalate ->
        {:ok, %{
          state: "escalate",
          sentiment: "negative",
          confidence: 0.85,
          reasons: ["technical support or system issue detected"],
          recommended_reply: nil
        }}

      sentiment == "negative" ->
        {:ok, %{
          state: "review",
          sentiment: "negative",
          confidence: sentiment_confidence,
          reasons: ["negative user feedback"],
          recommended_reply: nil
        }}

      # Low engagement neutral check
      String.length(text) <= 15 and Enum.any?(["ok", "cool", "nice", "hello", "hi", "hey", "thanks", "thx", "yep", "yes", "no"], &String.contains?(downcased, &1)) ->
        {:ok, %{
          state: "no-action",
          sentiment: "neutral",
          confidence: 0.8,
          reasons: ["low-engagement neutral greeting/acknowledgement"],
          recommended_reply: nil
        }}

      sentiment == "positive" ->
        {:ok, %{
          state: "reply",
          sentiment: "positive",
          confidence: sentiment_confidence,
          reasons: ["positive feedback"],
          recommended_reply: "Thank you so much for the support! Glad you found it helpful."
        }}

      # Default state
      true ->
        {:ok, %{
          state: "review",
          sentiment: "neutral",
          confidence: 0.5,
          reasons: ["unclassified comment pattern"],
          recommended_reply: nil
        }}
    end
  end

  defp get_sentiment(text) do
    case Lux.Prisms.SentimentAnalysisPrism.run(%{text: text, language: "en"}) do
      {:ok, %{sentiment: sentiment, confidence: confidence}} ->
        {sentiment, confidence}
      {:ok, %{"sentiment" => sentiment, "confidence" => confidence}} ->
        {sentiment, confidence}
      _ ->
        fallback_sentiment(text)
    end
  end

  defp fallback_sentiment(text) do
    downcased = String.downcase(text)

    # Simple list of positive/negative words
    pos_words = ["love", "great", "awesome", "perfect", "good", "amazing", "helpful", "nice", "excellent", "thanks", "thank you"]
    neg_words = ["bad", "worst", "hate", "terrible", "spammer", "scam", "sucks", "useless", "disappointed", "shit", "fuck", "annoying"]

    pos_count = Enum.count(pos_words, &String.contains?(downcased, &1))
    neg_count = Enum.count(neg_words, &String.contains?(downcased, &1))

    cond do
      pos_count > neg_count -> {"positive", 0.7}
      neg_count > pos_count -> {"negative", 0.7}
      true -> {"neutral", 0.5}
    end
  end
end
