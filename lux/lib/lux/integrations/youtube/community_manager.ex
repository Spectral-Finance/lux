defmodule Lux.Integrations.YouTube.CommunityManager do
  @moduledoc """
  Deterministic YouTube community management and engagement toolkit.

  The manager turns imported YouTube comments, subscriber events, channel goals,
  and campaign briefs into moderation decisions, response suggestions, community
  post schedules, subscriber interaction patterns, cross-platform promotion
  plans, and engagement campaign summaries. It is intentionally offline and
  side-effect free so agents can use it without channel credentials.
  """

  @positive_words ~w(great love awesome excellent helpful thanks thank amazing useful clear win bullish excited)
  @negative_words ~w(bad hate scam fake terrible broken wrong disappointed angry bearish useless issue problem)
  @spam_words ~w(giveaway airdrop free money click subscribe promo pump guaranteed dm whatsapp telegram)

  @doc """
  Builds a full community management report from imported channel data.
  """
  @spec run(map()) :: {:ok, map()} | {:error, String.t()}
  def run(input), do: build_report(input)

  @spec build_report(map()) :: {:ok, map()} | {:error, String.t()}
  def build_report(input) when is_map(input) do
    comments = comments(input)
    subscriber_events = subscriber_events(input)
    campaigns = campaigns(input)

    analysis = analyze_comments(comments)
    moderation = moderation_queue(analysis)

    {:ok,
     %{
       channel: value(input, :channel, "YouTube channel"),
       goals: list_value(input, :goals),
       comment_management: %{
         summary: comment_summary(analysis),
         analyzed_comments: analysis,
         response_queue: response_queue(analysis),
         top_discussion_threads: top_threads(comments)
       },
       automated_response_generation: response_playbook(analysis, input),
       sentiment_analysis: sentiment_report(analysis),
       moderation_system: %{
         queue: moderation,
         policy: moderation_policy(input),
         spam_patterns: spam_patterns(analysis)
       },
       community_post_schedule: community_post_schedule(input, analysis),
       subscriber_interaction_patterns: subscriber_patterns(subscriber_events, analysis),
       cross_platform_promotion: cross_platform_plan(input),
       engagement_campaign_management: campaign_management(campaigns, analysis),
       fan_interaction_automation: automation_rules(analysis, input)
     }}
  end

  def build_report(_input), do: {:error, "Expected a map with YouTube community data"}

  @doc """
  Normalizes and classifies comments by sentiment, intent, spam risk, and action.
  """
  @spec analyze_comments([map()]) :: [map()]
  def analyze_comments(comments) when is_list(comments) do
    comments
    |> Enum.with_index(1)
    |> Enum.map(fn {comment, index} ->
      text = string_value(comment, :text, "")
      sentiment = sentiment(text)
      spam_score = spam_score(text)
      intent = intent(text, sentiment, spam_score)
      influence = influence_score(comment)

      %{
        id: value(comment, :id, "comment-#{index}"),
        author: value(comment, :author, "viewer"),
        text: text,
        sentiment: sentiment.label,
        sentiment_score: sentiment.score,
        intent: intent,
        spam_score: spam_score,
        influence_score: influence,
        priority: priority(sentiment, spam_score, influence, intent),
        recommended_action: recommended_action(sentiment, spam_score, intent),
        response: suggested_response(text, intent, sentiment),
        moderation_reason: moderation_reason(text, spam_score, sentiment)
      }
    end)
  end

  def analyze_comments(_comments), do: []

  @doc """
  Returns only comments that should be reviewed, hidden, escalated, or answered.
  """
  @spec moderation_queue([map()]) :: [map()]
  def moderation_queue(analysis) do
    analysis
    |> Enum.filter(&(&1.recommended_action in [:hide, :review, :escalate, :reply]))
    |> Enum.sort_by(&{priority_rank(&1.priority), &1.spam_score, abs(&1.sentiment_score)}, :desc)
  end

  defp comment_summary(analysis) do
    total = length(analysis)
    counts = Enum.frequencies_by(analysis, & &1.sentiment)
    actions = Enum.frequencies_by(analysis, & &1.recommended_action)

    %{
      total_comments: total,
      positive: Map.get(counts, :positive, 0),
      neutral: Map.get(counts, :neutral, 0),
      negative: Map.get(counts, :negative, 0),
      spam: Enum.count(analysis, &(&1.spam_score >= 70)),
      needs_reply: Map.get(actions, :reply, 0) + Map.get(actions, :escalate, 0),
      needs_moderation: Map.get(actions, :hide, 0) + Map.get(actions, :review, 0)
    }
  end

  defp response_queue(analysis) do
    analysis
    |> Enum.filter(&(&1.recommended_action in [:reply, :escalate]))
    |> Enum.map(fn item ->
      %{
        comment_id: item.id,
        author: item.author,
        priority: item.priority,
        intent: item.intent,
        response: item.response,
        escalation: item.recommended_action == :escalate
      }
    end)
  end

  defp top_threads(comments) do
    comments
    |> Enum.map(fn comment ->
      %{
        id: value(comment, :id, nil),
        author: value(comment, :author, "viewer"),
        text: string_value(comment, :text, ""),
        replies: integer_value(comment, :replies, 0),
        likes: integer_value(comment, :likes, 0),
        score: integer_value(comment, :likes, 0) + integer_value(comment, :replies, 0) * 3
      }
    end)
    |> Enum.sort_by(& &1.score, :desc)
    |> Enum.take(5)
  end

  defp response_playbook(analysis, input) do
    %{
      tone: value(input, :response_tone, "helpful, concise, and brand-safe"),
      templates: %{
        question: "Thanks for asking. Short answer: %{answer}. Full walkthrough: %{resource}.",
        complaint:
          "Thanks for flagging this. We are checking the issue and will follow up with details.",
        praise: "Thanks for watching. Glad this helped.",
        request: "Good suggestion. We will consider this for a future video or community post.",
        spam: "Do not respond. Hide or report if the account repeats this pattern."
      },
      generated: response_queue(analysis)
    }
  end

  defp sentiment_report(analysis) do
    scores = Enum.map(analysis, & &1.sentiment_score)

    %{
      average_score: round_number(avg(scores)),
      distribution: Enum.frequencies_by(analysis, & &1.sentiment),
      themes: %{
        questions: Enum.count(analysis, &(&1.intent == :question)),
        complaints: Enum.count(analysis, &(&1.intent == :complaint)),
        requests: Enum.count(analysis, &(&1.intent == :request)),
        praise: Enum.count(analysis, &(&1.intent == :praise))
      },
      alerts:
        analysis
        |> Enum.filter(&(&1.sentiment == :negative and &1.influence_score >= 50))
        |> Enum.map(
          &%{comment_id: &1.id, author: &1.author, reason: "negative high-influence comment"}
        )
    }
  end

  defp moderation_policy(input) do
    %{
      hide_spam_at: integer_value(input, :hide_spam_at, 85),
      review_spam_at: integer_value(input, :review_spam_at, 60),
      escalate_negative_influence_at: integer_value(input, :escalate_negative_influence_at, 50),
      rules: [
        "Hide obvious scam, giveaway, and impersonation comments.",
        "Review comments with links, repeated promotions, or aggressive claims.",
        "Escalate high-influence negative feedback before responding.",
        "Reply to questions and useful feature requests within the target SLA."
      ]
    }
  end

  defp spam_patterns(analysis) do
    analysis
    |> Enum.filter(&(&1.spam_score > 0))
    |> Enum.map(&%{comment_id: &1.id, spam_score: &1.spam_score, reason: &1.moderation_reason})
  end

  defp community_post_schedule(input, analysis) do
    topics = list_value(input, :content_topics)
    goals = list_value(input, :goals)
    question_count = Enum.count(analysis, &(&1.intent == :question))
    complaint_count = Enum.count(analysis, &(&1.intent == :complaint))

    topics =
      if topics == [], do: ["weekly market note", "viewer Q&A", "feature update"], else: topics

    %{
      cadence: value(input, :post_cadence, "3 posts per week"),
      posts:
        topics
        |> Enum.take(6)
        |> Enum.with_index(1)
        |> Enum.map(fn {topic, index} ->
          %{
            day_offset: index * 2,
            topic: topic,
            format: post_format(index),
            prompt: post_prompt(topic, goals, question_count, complaint_count),
            success_metric: post_metric(index)
          }
        end)
    }
  end

  defp subscriber_patterns(events, analysis) do
    sources = events |> Enum.map(&value(&1, :source, "unknown")) |> Enum.frequencies()
    segments = events |> Enum.map(&value(&1, :segment, "general")) |> Enum.frequencies()
    total = length(events)

    %{
      total_events: total,
      source_mix: sources,
      segments: segments,
      interaction_windows: best_windows(events),
      recommended_segments: recommended_segments(segments, analysis)
    }
  end

  defp cross_platform_plan(input) do
    platforms = list_value(input, :platforms)

    platforms =
      if platforms == [], do: ["x", "telegram", "discord", "newsletter"], else: platforms

    platforms
    |> Enum.map(fn platform ->
      %{
        platform: platform,
        asset: platform_asset(platform),
        message_angle: platform_angle(platform, input),
        tracking: "utm_source=#{platform}&utm_campaign=youtube_community"
      }
    end)
  end

  defp campaign_management(campaigns, analysis) do
    campaigns
    |> Enum.map(fn campaign ->
      goal = value(campaign, :goal, "engagement")
      baseline = number_value(campaign, :baseline, 0)
      target = number_value(campaign, :target, baseline)
      progress = number_value(campaign, :current, baseline)

      %{
        name: value(campaign, :name, goal),
        goal: goal,
        status: campaign_status(progress, target),
        progress_rate: ratio(progress - baseline, max(target - baseline, 1)),
        next_actions: campaign_actions(goal, analysis)
      }
    end)
  end

  defp automation_rules(analysis, input) do
    %{
      reply_sla_hours: integer_value(input, :reply_sla_hours, 12),
      rules: [
        %{when: "question and not spam", action: "queue response suggestion"},
        %{when: "spam_score >= 85", action: "hide and log pattern"},
        %{when: "negative and influence_score >= 50", action: "escalate to human"},
        %{when: "praise from repeat viewer", action: "reply and invite to community post"}
      ],
      queue_size: length(response_queue(analysis))
    }
  end

  defp sentiment(text) do
    words = words(text)
    positive = Enum.count(words, &(&1 in @positive_words))
    negative = Enum.count(words, &(&1 in @negative_words))
    score = clamp((positive - negative) / max(length(words), 1) * 4, -1, 1)

    label =
      cond do
        score > 0.12 -> :positive
        score < -0.12 -> :negative
        true -> :neutral
      end

    %{label: label, score: round_number(score)}
  end

  defp spam_score(text) do
    downcased = String.downcase(text)
    words = words(downcased)
    keyword_score = Enum.count(words, &(&1 in @spam_words)) * 22
    link_score = if Regex.match?(~r/https?:\/\/|www\./, downcased), do: 25, else: 0
    mention_score = if Regex.match?(~r/@\w+.*@\w+/, downcased), do: 15, else: 0
    repetition_score = if Regex.match?(~r/(.)\1{5,}/, downcased), do: 20, else: 0

    min(keyword_score + link_score + mention_score + repetition_score, 100)
  end

  defp intent(text, sentiment, spam_score) do
    downcased = String.downcase(text)

    cond do
      spam_score >= 70 ->
        :spam

      String.contains?(downcased, "?") or
          Regex.match?(~r/\b(how|what|why|when|can|does)\b/, downcased) ->
        :question

      sentiment.label == :negative ->
        :complaint

      Regex.match?(~r/\b(please|could|feature|add|request|suggest)\b/, downcased) ->
        :request

      sentiment.label == :positive ->
        :praise

      true ->
        :comment
    end
  end

  defp priority(sentiment, spam_score, influence, intent) do
    cond do
      spam_score >= 85 -> :urgent
      sentiment.label == :negative and influence >= 50 -> :urgent
      intent in [:question, :complaint] -> :high
      spam_score >= 60 -> :medium
      true -> :normal
    end
  end

  defp recommended_action(sentiment, spam_score, intent) do
    cond do
      spam_score >= 85 -> :hide
      spam_score >= 60 -> :review
      sentiment.label == :negative -> :escalate
      intent in [:question, :request, :praise] -> :reply
      true -> :monitor
    end
  end

  defp suggested_response(_text, :spam, _sentiment), do: nil

  defp suggested_response(_text, :question, _sentiment),
    do: "Thanks for asking. Here is the short answer, plus a link to the deeper walkthrough."

  defp suggested_response(_text, :request, _sentiment),
    do:
      "Good suggestion. We are adding this to the content backlog and will prioritize it with similar requests."

  defp suggested_response(_text, :complaint, _sentiment),
    do:
      "Thanks for flagging this. We are checking the issue and will follow up with a specific fix or clarification."

  defp suggested_response(_text, :praise, _sentiment),
    do: "Thanks for watching. Glad this helped."

  defp suggested_response(_text, _intent, _sentiment),
    do: "Thanks for watching and sharing feedback."

  defp moderation_reason(_text, spam_score, sentiment) do
    cond do
      spam_score >= 85 -> "high spam score from promotional language or links"
      spam_score >= 60 -> "medium spam score; needs review"
      sentiment.label == :negative -> "negative sentiment; consider human response"
      true -> nil
    end
  end

  defp influence_score(comment) do
    likes = integer_value(comment, :likes, 0)
    replies = integer_value(comment, :replies, 0)
    subscribers = integer_value(comment, :author_subscribers, 0)
    min(likes * 2 + replies * 5 + min(div(subscribers, 1_000), 50), 100)
  end

  defp best_windows(events) do
    events
    |> Enum.map(&value(&1, :hour, nil))
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_hour, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {hour, count} -> %{hour: hour, events: count} end)
  end

  defp recommended_segments(segments, analysis) do
    top =
      segments
      |> Enum.sort_by(fn {_segment, count} -> count end, :desc)
      |> Enum.take(3)
      |> Enum.map(fn {segment, count} -> %{segment: segment, count: count} end)

    if Enum.any?(analysis, &(&1.intent == :question)) do
      [
        %{segment: "question askers", count: Enum.count(analysis, &(&1.intent == :question))}
        | top
      ]
    else
      top
    end
  end

  defp post_format(index) do
    Enum.at(
      ["poll", "behind-the-scenes note", "question prompt", "short clip teaser"],
      rem(index - 1, 4)
    )
  end

  defp post_prompt(topic, goals, question_count, complaint_count) do
    "Discuss #{topic}; tie to #{Enum.join(goals, ", ")}; address #{question_count} questions and #{complaint_count} complaints from recent comments."
  end

  defp post_metric(index) do
    Enum.at(
      ["comments per post", "poll votes", "returning viewers", "click-through rate"],
      rem(index - 1, 4)
    )
  end

  defp platform_asset("x"), do: "short thread with one chart and one viewer question"
  defp platform_asset("twitter"), do: platform_asset("x")
  defp platform_asset("telegram"), do: "channel post with summary, link, and discussion prompt"
  defp platform_asset("discord"), do: "discussion starter plus moderator response checklist"
  defp platform_asset("newsletter"), do: "weekly community digest"
  defp platform_asset(_platform), do: "short post adapted from the latest community insight"

  defp platform_angle(platform, input) do
    topic = value(input, :primary_topic, "the newest video")
    "Use #{platform} to bring viewers back to #{topic} with one clear question."
  end

  defp campaign_status(progress, target) when progress >= target, do: :complete
  defp campaign_status(progress, target) when progress >= target * 0.7, do: :on_track
  defp campaign_status(_progress, _target), do: :needs_attention

  defp campaign_actions(goal, analysis) do
    [
      "Turn top viewer questions into a community post for #{goal}.",
      "Reply to #{Enum.count(analysis, &(&1.recommended_action == :reply))} queued comments.",
      "Review #{Enum.count(analysis, &(&1.recommended_action in [:hide, :review]))} moderation items before next promotion."
    ]
  end

  defp comments(input), do: list_of_maps(input, :comments)
  defp subscriber_events(input), do: list_of_maps(input, :subscriber_events)
  defp campaigns(input), do: list_of_maps(input, :campaigns)

  defp words(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s]/, " ")
    |> String.split()
  end

  defp list_of_maps(input, key) do
    input
    |> value(key, [])
    |> case do
      list when is_list(list) -> Enum.filter(list, &is_map/1)
      _ -> []
    end
  end

  defp list_value(input, key) do
    case value(input, key, []) do
      list when is_list(list) -> Enum.map(list, &to_string/1)
      value when is_binary(value) and value != "" -> [value]
      _ -> []
    end
  end

  defp string_value(input, key, default), do: input |> value(key, default) |> to_string()

  defp integer_value(input, key, default) do
    case value(input, key, default) do
      value when is_integer(value) ->
        value

      value when is_float(value) ->
        round(value)

      value when is_binary(value) ->
        case Integer.parse(value) do
          {number, _rest} -> number
          :error -> default
        end

      _ ->
        default
    end
  end

  defp number_value(input, key, default) do
    case value(input, key, default) do
      value when is_integer(value) ->
        value * 1.0

      value when is_float(value) ->
        value

      value when is_binary(value) ->
        case Float.parse(value) do
          {number, _rest} -> number
          :error -> default
        end

      _ ->
        default
    end
  end

  defp value(map, key, default) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end

  defp avg([]), do: 0
  defp avg(values), do: Enum.sum(values) / length(values)

  defp ratio(_numerator, denominator) when denominator in [0, 0.0], do: 0
  defp ratio(numerator, denominator), do: round_number(numerator / denominator)

  defp round_number(value) when is_float(value), do: Float.round(value, 4)
  defp round_number(value), do: value

  defp clamp(value, min, _max) when value < min, do: min
  defp clamp(value, _min, max) when value > max, do: max
  defp clamp(value, _min, _max), do: value

  defp priority_rank(:urgent), do: 4
  defp priority_rank(:high), do: 3
  defp priority_rank(:medium), do: 2
  defp priority_rank(:normal), do: 1
end
