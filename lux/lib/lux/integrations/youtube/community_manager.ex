defmodule Lux.Integrations.YouTube.CommunityManager do
  @moduledoc """
  YouTube community-management and engagement helpers.

  The module classifies comments, suggests responses, detects moderation risk,
  schedules community posts, groups subscriber interactions, and plans
  cross-platform engagement campaigns.
  """

  @spam_terms ["free crypto", "whatsapp", "telegram me", "investment guaranteed", "click my profile"]
  @positive_terms ["thanks", "great", "love", "helpful", "awesome", "excellent"]
  @negative_terms ["hate", "broken", "scam", "bad", "useless", "angry"]

  @doc """
  Analyzes a YouTube comment for sentiment, intent, and moderation risk.
  """
  @spec analyze_comment(map()) :: map()
  def analyze_comment(comment) when is_map(comment) do
    text = value(comment, :text) || ""
    sentiment = sentiment(text)
    spam_score = spam_score(text)

    %{
      comment_id: value(comment, :id),
      author_channel_id: value(comment, :author_channel_id),
      text: text,
      sentiment: sentiment,
      intent: intent(text),
      spam_score: spam_score,
      moderation: moderation_decision(spam_score, sentiment, text)
    }
  end

  @doc """
  Suggests a response for a classified comment.
  """
  @spec response_suggestion(map(), map()) :: map()
  def response_suggestion(comment_or_analysis, opts \\ %{}) do
    analysis =
      if Map.has_key?(comment_or_analysis, :intent) do
        comment_or_analysis
      else
        analyze_comment(comment_or_analysis)
      end

    template =
      case analysis.intent do
        :question -> "Thanks for the question. Here is the short answer: #{value(opts, :answer) || "we will cover this in a follow-up."}"
        :complaint -> "Thanks for flagging this. We will review it and improve the next version."
        :praise -> "Thanks for watching and for the kind words."
        :spam -> nil
        _intent -> value(opts, :default_response) || "Thanks for watching and joining the discussion."
      end

    %{
      comment_id: analysis.comment_id,
      response: template,
      should_reply?: not is_nil(template) and analysis.moderation.action == :allow,
      moderation_action: analysis.moderation.action
    }
  end

  @doc """
  Builds moderation decisions for a batch of comments.
  """
  @spec moderation_queue([map()]) :: [map()]
  def moderation_queue(comments) when is_list(comments) do
    comments
    |> Enum.map(&analyze_comment/1)
    |> Enum.map(fn analysis ->
      %{
        comment_id: analysis.comment_id,
        action: analysis.moderation.action,
        reason: analysis.moderation.reason,
        spam_score: analysis.spam_score,
        sentiment: analysis.sentiment
      }
    end)
  end

  @doc """
  Schedules a community post.
  """
  @spec schedule_post(map()) :: map()
  def schedule_post(attrs) when is_map(attrs) do
    %{
      id: value(attrs, :id) || "community-#{:erlang.phash2({value(attrs, :text), value(attrs, :scheduled_at)})}",
      text: value(attrs, :text),
      scheduled_at: value(attrs, :scheduled_at),
      poll_options: value(attrs, :poll_options) || [],
      media: value(attrs, :media) || [],
      state: value(attrs, :state) || :scheduled,
      campaign_id: value(attrs, :campaign_id)
    }
  end

  @doc """
  Summarizes subscriber interaction patterns.
  """
  @spec interaction_patterns([map()]) :: map()
  def interaction_patterns(events) when is_list(events) do
    by_author = Enum.group_by(events, &value(&1, :author_channel_id))

    %{
      unique_authors: map_size(by_author),
      repeat_authors: by_author |> Enum.count(fn {_author, items} -> length(items) > 1 end),
      top_authors:
        by_author
        |> Enum.map(fn {author, items} -> %{author_channel_id: author, interaction_count: length(items)} end)
        |> Enum.sort_by(& &1.interaction_count, :desc)
        |> Enum.take(5),
      event_mix: event_mix(events)
    }
  end

  @doc """
  Builds cross-platform promotion tasks for a YouTube asset.
  """
  @spec promotion_plan(map()) :: [map()]
  def promotion_plan(attrs) when is_map(attrs) do
    title = value(attrs, :title) || "New YouTube video"
    url = value(attrs, :url)

    [
      %{platform: :x, copy: "#{title} #{url}", timing: :launch},
      %{platform: :linkedin, copy: "New video: #{title}\n\n#{url}", timing: :launch_plus_2_hours},
      %{platform: :newsletter, copy: "Feature this video in the next newsletter: #{title}", timing: :next_issue}
    ]
  end

  @doc """
  Creates an engagement campaign summary.
  """
  @spec campaign(map()) :: map()
  def campaign(attrs) when is_map(attrs) do
    comments = value(attrs, :comments) || []

    %{
      campaign_id: value(attrs, :campaign_id),
      objective: value(attrs, :objective) || :engagement,
      moderation_queue: moderation_queue(comments),
      responses: Enum.map(comments, &response_suggestion/1),
      community_posts: Enum.map(value(attrs, :community_posts) || [], &schedule_post/1),
      interactions: interaction_patterns(value(attrs, :events) || comments),
      promotion: promotion_plan(attrs)
    }
  end

  defp sentiment(text) do
    normalized = String.downcase(text)
    positive_hits = count_terms(normalized, @positive_terms)
    negative_hits = count_terms(normalized, @negative_terms)

    cond do
      positive_hits > negative_hits -> :positive
      negative_hits > positive_hits -> :negative
      true -> :neutral
    end
  end

  defp intent(text) do
    normalized = String.downcase(text)

    cond do
      spam_score(text) >= 0.7 -> :spam
      String.contains?(normalized, "?") -> :question
      count_terms(normalized, @negative_terms) > 0 -> :complaint
      count_terms(normalized, @positive_terms) > 0 -> :praise
      true -> :general
    end
  end

  defp spam_score(text) do
    normalized = String.downcase(text)
    hits = count_terms(normalized, @spam_terms)
    min(hits / 2, 1.0)
  end

  defp moderation_decision(spam_score, sentiment, text) do
    cond do
      spam_score >= 0.7 ->
        %{action: :hide, reason: :spam}

      String.length(text) > 1_000 ->
        %{action: :review, reason: :too_long}

      sentiment == :negative ->
        %{action: :review, reason: :negative_sentiment}

      true ->
        %{action: :allow, reason: :clean}
    end
  end

  defp event_mix(events) do
    events
    |> Enum.frequencies_by(&(value(&1, :type) || :comment))
  end

  defp count_terms(text, terms), do: Enum.count(terms, &String.contains?(text, &1))

  defp value(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
  defp value(_map, _key), do: nil
end
