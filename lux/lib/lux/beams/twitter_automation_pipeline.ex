defmodule Lux.Beams.TwitterAutomationPipeline do
  @moduledoc """
  A beam that orchestrates the complete Twitter automation and engagement pipeline.

  Chains together lenses (data collection) and prisms (content transformation)
  to create an end-to-end workflow for Twitter automation:

  1. Collect timeline data and engagement metrics
  2. Discover and curate trending content
  3. Schedule tweets based on optimal engagement times
  4. Manage auto-replies to mentions and DMs
  5. Generate content calendar
  6. Execute engagement rules

  ## Example

      iex> Lux.Beams.TwitterAutomationPipeline.run(%{
      ...>   user_id: "12345",
      ...>   keywords: ["elixir", "web3"],
      ...>   action: "full_automation"
      ...> })
      {:ok, %{timeline: %{...}, engagement: %{...}, scheduled: %{...}, ...}}
  """

  use Lux.Beam,
    name: "Twitter Automation Pipeline",
    description: "End-to-end Twitter automation pipeline: timeline → engagement → curation → scheduling → auto-reply → calendar",
    input_schema: %{
      type: :object,
      properties: %{
        user_id: %{
          type: :string,
          description: "Twitter user ID for the account being managed"
        },
        keywords: %{
          type: :array,
          items: %{type: :string},
          description: "Keywords for content curation"
        },
        hashtags: %{
          type: :array,
          items: %{type: :string},
          description: "Hashtags to monitor"
        },
        action: %{
          type: :string,
          description: "Pipeline action to perform",
          enum: ["full_automation", "analytics_only", "content_only", "engagement_only"],
          default: "full_automation"
        },
        schedule_tweets: %{
          type: :boolean,
          description: "Whether to schedule new tweets",
          default: true
        },
        auto_reply: %{
          type: :boolean,
          description: "Whether to process auto-replies",
          default: true
        },
        generate_calendar: %{
          type: :boolean,
          description: "Whether to generate content calendar",
          default: true
        },
        execute_engagement: %{
          type: :boolean,
          description: "Whether to execute engagement rules",
          default: true
        },
        timezone: %{
          type: :string,
          description: "Target timezone",
          default: "UTC"
        },
        max_tweets_to_analyze: %{
          type: :integer,
          description: "Maximum tweets to analyze from timeline",
          default: 20
        },
        min_engagement_threshold: %{
          type: :integer,
          description: "Minimum engagement for content curation",
          default: 10
        }
      },
      required: ["user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        timeline_data: %{
          type: :object,
          description: "Timeline data from TwitterTimelineLens"
        },
        engagement_metrics: %{
          type: :object,
          description: "Engagement metrics from EngagementMetricsLens"
        },
        curated_content: %{
          type: :object,
          description: "Curated content from ContentCurationLens"
        },
        scheduled_tweets: %{
          type: :array,
          description: "Scheduled tweet results from TweetSchedulerPrism"
        },
        auto_replies: %{
          type: :array,
          description: "Auto-reply results from AutoReplyPrism"
        },
        content_calendar: %{
          type: :object,
          description: "Content calendar from ContentCalendarPrism"
        },
        engagement_actions: %{
          type: :array,
          description: "Engagement rule execution results from EngagementRulesPrism"
        },
        pipeline_status: %{
          type: :string,
          enum: ["success", "partial", "error"]
        },
        summary: %{
          type: :object,
          description: "Pipeline execution summary"
        }
      }
    }

  @doc """
  Runs the complete Twitter automation pipeline.
  """
  def run(params) do
    user_id = Map.get(params, :user_id, params["user_id"])
    keywords = Map.get(params, :keywords, params["keywords"] || [])
    hashtags = Map.get(params, :hashtags, params["hashtags"] || [])
    action = Map.get(params, :action, params["action"] || "full_automation")
    schedule_tweets = Map.get(params, :schedule_tweets, params["schedule_tweets"] || true)
    auto_reply = Map.get(params, :auto_reply, params["auto_reply"] || true)
    generate_calendar = Map.get(params, :generate_calendar, params["generate_calendar"] || true)
    execute_engagement = Map.get(params, :execute_engagement, params["execute_engagement"] || true)
    timezone = Map.get(params, :timezone, params["timezone"] || "UTC")
    max_tweets = Map.get(params, :max_tweets_to_analyze, params["max_tweets_to_analyze"] || 20)
    min_engagement = Map.get(params, :min_engagement_threshold, params["min_engagement_threshold"] || 10)

    # Step 1: Collect timeline data
    timeline_result = collect_timeline(user_id, max_tweets)

    # Step 2: Collect engagement metrics
    engagement_result = collect_engagement_metrics(user_id)

    # Step 3: Curate content
    curated_result = curate_content(keywords, hashtags, min_engagement)

    # Step 4: Schedule tweets (if enabled)
    scheduled_result = if schedule_tweets do
      schedule_tweets_action(curated_result, timezone)
    else
      {:ok, %{message: "Tweet scheduling disabled"}}
    end

    # Step 5: Process auto-replies (if enabled)
    auto_reply_result = if auto_reply do
      process_auto_replies(timeline_result)
    else
      {:ok, %{message: "Auto-reply processing disabled"}}
    end

    # Step 6: Generate content calendar (if enabled)
    calendar_result = if generate_calendar do
      generate_content_calendar(timezone)
    else
      {:ok, %{message: "Content calendar generation disabled"}}
    end

    # Step 7: Execute engagement rules (if enabled)
    engagement_actions_result = if execute_engagement do
      execute_engagement_rules(curated_result, timeline_result)
    else
      {:ok, %{message: "Engagement rule execution disabled"}}
    end

    # Compile results
    {pipeline_status, summary} = compile_results(%{
      timeline: timeline_result,
      engagement: engagement_result,
      curated: curated_result,
      scheduled: scheduled_result,
      auto_replies: auto_reply_result,
      calendar: calendar_result,
      engagement_actions: engagement_actions_result
    })

    result = %{
      timeline_data: extract_result(timeline_result),
      engagement_metrics: extract_result(engagement_result),
      curated_content: extract_result(curated_result),
      scheduled_tweets: extract_list_result(scheduled_result),
      auto_replies: extract_list_result(auto_reply_result),
      content_calendar: extract_result(calendar_result),
      engagement_actions: extract_list_result(engagement_actions_result),
      pipeline_status: pipeline_status,
      summary: summary
    }

    {:ok, result}
  end

  defp collect_timeline(user_id, max_tweets) do
    Lux.Lenses.Twitter.TwitterTimelineLens.focus(%{
      user_id: user_id,
      max_results: max_tweets,
      exclude: "retweets"
    })
  rescue
    error -> {:error, "Timeline collection failed: #{inspect(error)}"}
  end

  defp collect_engagement_metrics(user_id) do
    Lux.Lenses.Twitter.EngagementMetricsLens.focus(%{
      user_id: user_id,
      metric_types: ["likes", "retweets", "replies", "impressions", "bookmarks"]
    })
  rescue
    error -> {:error, "Engagement metrics collection failed: #{inspect(error)}"}
  end

  defp curate_content(keywords, hashtags, min_engagement) do
    Lux.Lenses.Twitter.ContentCurationLens.focus(%{
      keywords: keywords,
      hashtags: hashtags,
      min_engagement: min_engagement,
      max_results: 20,
      exclude_retweets: true
    })
  rescue
    error -> {:error, "Content curation failed: #{inspect(error)}"}
  end

  defp schedule_tweets_action(curated_result, timezone) do
    case curated_result do
      {:ok, %{curated: curated}} when is_list(curated) and curated != [] ->
        Enum.take(curated, 3)
        |> Enum.map(fn content ->
          Lux.Prisms.Twitter.TweetSchedulerPrism.run(%{
            content: content[:text] || content["text"] || "",
            content_type: content[:content_type] || content["content_type"] || "text",
            timezone: timezone
          })
        end)

      _ ->
        {:ok, %{message: "No curated content available for scheduling"}}
    end
  end

  defp process_auto_replies(timeline_result) do
    case timeline_result do
      {:ok, %{tweets: tweets}} when is_list(tweets) and tweets != [] ->
        Enum.take(tweets, 5)
        |> Enum.map(fn tweet ->
          Lux.Prisms.Twitter.AutoReplyPrism.run(%{
            tweet_id: tweet[:id] || tweet["id"] || "",
            text: tweet[:text] || tweet["text"] || "",
            author_id: tweet[:author_id] || tweet["author_id"] || "",
            message_type: "mention"
          })
        end)

      _ ->
        {:ok, %{message: "No tweets available for auto-reply processing"}}
    end
  end

  defp generate_content_calendar(timezone) do
    Lux.Prisms.Twitter.ContentCalendarPrism.run(%{
      week_start: Date.utc_today() |> Date.to_iso8601(),
      duration_weeks: 1,
      posts_per_day: 2,
      content_categories: ["analysis", "news", "engagement", "educational", "community"],
      timezone: timezone,
      tone: "professional"
    })
  rescue
    error -> {:error, "Content calendar generation failed: #{inspect(error)}"}
  end

  defp execute_engagement_rules(curated_result, timeline_result) do
    actions = []

    # Engagement rules for curated content
    actions = case curated_result do
      {:ok, %{curated: curated}} when is_list(curated) ->
        Enum.take(curated, 3)
        |> Enum.map(fn content ->
          Lux.Prisms.Twitter.EngagementRulesPrism.run(%{
            action: "like",
            tweet_id: content[:id] || content["id"] || "",
            tweet_text: content[:text] || content["text"] || "",
            dry_run: true
          })
        end)
      _ -> []
    end

    # Engagement rules for timeline tweets
    actions = case timeline_result do
      {:ok, %{tweets: tweets}} when is_list(tweets) ->
        actions ++ Enum.take(tweets, 3)
        |> Enum.map(fn tweet ->
          Lux.Prisms.Twitter.EngagementRulesPrism.run(%{
            action: "retweet",
            tweet_id: tweet[:id] || tweet["id"] || "",
            tweet_text: tweet[:text] || tweet["text"] || "",
            dry_run: true
          })
        end)
      _ -> actions
    end

    {:ok, %{actions: actions, count: length(actions)}}
  rescue
    error -> {:error, "Engagement rules execution failed: #{inspect(error)}"}
  end

  defp compile_results(results) do
    %{timeline: timeline, engagement: engagement, curated: curated,
      scheduled: scheduled, auto_replies: auto_replies, calendar: calendar,
      engagement_actions: engagement_actions} = results

    # Determine pipeline status
    statuses = [timeline, engagement, curated, scheduled, auto_replies, calendar, engagement_actions]
    success_count = Enum.count(statuses, &(elem(&1, 0) == :ok))
    total = length(statuses)

    pipeline_status = case success_count do
      ^total -> "success"
      count when count >= div(total, 2) -> "partial"
      _ -> "error"
    end

    # Build summary
    summary = %{
      total_steps: total,
      successful_steps: success_count,
      failed_steps: total - success_count,
      timeline_tweets: case timeline do
        {:ok, data} -> data[:total_count] || data["total_count"] || 0
        _ -> 0
      end,
      engagement_rate: case engagement do
        {:ok, data} -> data[:average_engagement_rate] || data["average_engagement_rate"] || 0
        _ -> 0
      end,
      curated_items: case curated do
        {:ok, data} -> length(data[:curated] || data["curated"] || [])
        _ -> 0
      end,
      scheduled_count: case scheduled do
        {:ok, _} -> 1
        _ -> 0
      end,
      auto_reply_count: case auto_replies do
        {:ok, _} -> 1
        _ -> 0
      end
    }

    {pipeline_status, summary}
  end

  defp extract_result({:ok, data}), do: data
  defp extract_result({:error, reason}), do: %{error: reason}
  defp extract_result(_), do: %{}

  defp extract_list_result({:ok, data}) when is_list(data), do: data
  defp extract_list_result({:ok, %{actions: actions}}) when is_list(actions), do: actions
  defp extract_list_result({:ok, %{message: msg}}), do: [%{message: msg}]
  defp extract_list_result({:error, reason}), do: [%{error: reason}]
  defp extract_list_result(_), do: []
end
