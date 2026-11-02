defmodule Lux.Community.YouTube.ResponseGenerator do
  @moduledoc """
  Context-aware automated response generator for YouTube creator community engagement.

  Generates high-engagement replies aligned with creator personas, tailored for:
  - Praise: Expresses genuine gratitude and encourages community participation
  - Inquiries: Directs viewers to key sections, documentation, or planned sequels
  - Suggestions: Acknowledges creative ideas and logs content requests
  - Complaints: Empathetic de-escalation and technical clarification
  """

  alias Lux.Community.YouTube.SentimentAnalyzer

  @praise_replies [
    "Thank you so much for the support! Glad this was helpful to you! 🙌",
    "Appreciate you watching! More deep dives like this are on the way. 🚀",
    "Thanks for tuning in! Feel free to let me know what topics you'd like to see next!",
    "Much love! Comments like this keep the channel going strong. ❤️"
  ]

  @inquiry_replies [
    "Great question! I cover the exact breakdown in the video timestamps, and will do a follow-up deep dive soon!",
    "Thanks for asking! Check out the links in the video description for full code samples and documentation.",
    "Good catch! I'll be addressing this in detail in our next community livestream. Stay tuned!"
  ]

  @suggestion_replies [
    "Fantastic idea! I've added this to our production roadmap for an upcoming episode. Thanks for the suggestion! 💡",
    "Love this suggestion! We're planning a video around this exact topic soon.",
    "Noted! Appreciate you taking the time to share your feedback with us."
  ]

  @complaint_replies [
    "Thanks for the feedback! We're constantly improving our audio/video workflow and will make sure this is refined in the next upload.",
    "Appreciate you pointing this out! We'll look into it and add an update pinned comment if needed."
  ]

  @doc """
  Generates an engaging, contextual reply for a given comment text and author name.
  """
  @spec generate_response(String.t(), String.t(), keyword()) :: %{
          reply_text: String.t(),
          intent_detected: atom(),
          persona: String.t()
        }
  def generate_response(comment_text, author_name \\ "friend", opts \\ []) do
    persona = Keyword.get(opts, :persona, "Creator")
    analysis = SentimentAnalyzer.analyze_comment(comment_text)

    reply_base =
      case analysis.intent do
        :praise -> Enum.random(@praise_replies)
        :inquiry -> Enum.random(@inquiry_replies)
        :suggestion -> Enum.random(@suggestion_replies)
        :complaint -> Enum.random(@complaint_replies)
        :neutral -> "Thanks for watching and commenting! Have a great day!"
      end

    personalized =
      if author_name not in ["friend", "Anonymous", "", nil] do
        "Hey @#{author_name}, #{reply_base}"
      else
        reply_base
      end

    %{
      reply_text: personalized,
      intent_detected: analysis.intent,
      persona: persona
    }
  end

  @doc """
  Generates a list of suggested responses for a creator to choose from.
  """
  @spec generate_options(String.t(), String.t()) :: list(String.t())
  def generate_options(comment_text, author_name \\ "friend") do
    analysis = SentimentAnalyzer.analyze_comment(comment_text)

    pool =
      case analysis.intent do
        :praise -> @praise_replies
        :inquiry -> @inquiry_replies
        :suggestion -> @suggestion_replies
        :complaint -> @complaint_replies
        _ -> @praise_replies
      end

    prefix = if author_name not in ["friend", "Anonymous", "", nil], do: "@#{author_name} ", else: ""
    Enum.map(pool, fn template -> prefix <> template end)
  end
end
