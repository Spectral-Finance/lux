defmodule Lux.Community.YouTube do
  @moduledoc """
  Unified coordinator for YouTube Community Management and Engagement in Lux.

  Provides high-level APIs for:
  - Comment thread normalization and management (`normalize_comment/1`, `filter_comments/2`)
  - Automated sentiment scoring & audience intent categorization (`analyze_sentiment/1`, `analyze_batch_sentiment/1`)
  - Intelligent spam & scam filtering (`moderate_comment/1`, `moderate_batch/1`)
  - Persona-aligned contextual reply generation (`generate_reply/3`)
  - Community tab post scheduling (`schedule_post/1`, `recommend_optimal_window/1`)
  - End-to-end automated community moderation & response pipeline (`process_comment/2`)
  """

  alias Lux.Community.YouTube.{
    CommentManager,
    CommunityPostScheduler,
    ResponseGenerator,
    SentimentAnalyzer,
    SpamModerator
  }

  defdelegate normalize_comment(raw), to: CommentManager, as: :normalize_comment_thread
  defdelegate filter_comments(comments, opts), to: CommentManager
  defdelegate sort_comments(comments, sort_by), to: CommentManager
  defdelegate add_reply(comment, text, author), to: CommentManager
  defdelegate update_status(comment, status), to: CommentManager

  defdelegate analyze_sentiment(text), to: SentimentAnalyzer, as: :analyze_comment
  defdelegate analyze_batch_sentiment(comments), to: SentimentAnalyzer, as: :analyze_batch

  defdelegate moderate_comment(text), to: SpamModerator, as: :evaluate_comment
  defdelegate moderate_batch(comments), to: SpamModerator

  defdelegate generate_reply(text, author, opts \\ []), to: ResponseGenerator, as: :generate_response
  defdelegate generate_reply_options(text, author), to: ResponseGenerator, as: :generate_options

  defdelegate schedule_post(params), to: CommunityPostScheduler, as: :create_post
  defdelegate get_due_posts(queue, current_time), to: CommunityPostScheduler
  defdelegate recommend_optimal_window(tz \\ "UTC"), to: CommunityPostScheduler

  @doc """
  Runs an end-to-end community interaction pipeline on a comment.
  Returns moderation action, sentiment analysis, and recommended draft reply if applicable.
  """
  @spec process_comment(map() | String.t(), keyword()) :: map()
  def process_comment(comment, opts \\ []) do
    text = if is_map(comment), do: Map.get(comment, :text, Map.get(comment, "text", "")), else: to_string(comment)
    author = if is_map(comment), do: Map.get(comment, :author_name, Map.get(comment, "author_name", "Viewer")), else: "Viewer"

    moderation = moderate_comment(text)
    sentiment = analyze_sentiment(text)

    auto_reply =
      if moderation.recommended_action == :approve do
        generate_reply(text, author, opts)
      else
        nil
      end

    %{
      original_text: text,
      author: author,
      moderation: moderation,
      sentiment: sentiment,
      suggested_reply: auto_reply,
      should_publish_reply: moderation.recommended_action == :approve and sentiment.intent in [:praise, :inquiry]
    }
  end
end
