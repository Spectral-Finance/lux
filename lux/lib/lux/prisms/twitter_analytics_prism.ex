defmodule Lux.Prisms.TwitterAnalyticsPrism do
  @moduledoc """
  A Prism for autonomous agents to execute Twitter Analytics and Monitoring:
  - Aggregate engagement metrics and rank viral tweets
  - Analyze follower growth trajectories
  - Extract and evaluate hashtag trends
  - Run sentiment analysis on incoming mentions
  - Monitor engagement alert thresholds
  - Generate comprehensive executive reports
  """

  use Lux.Prism,
    name: "Twitter Analytics Prism",
    description: "Real-time engagement metrics, follower growth tracking, hashtag analysis, sentiment monitoring, and automated reporting for Twitter",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: [
            "track_engagement",
            "track_follower_growth",
            "analyze_hashtags",
            "analyze_sentiment",
            "check_alerts",
            "generate_report",
            "run_full_audit"
          ],
          description: "Analytics action to perform"
        },
        payload: %{
          type: :object,
          description: "Action-specific payload parameters"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        result: %{type: :object}
      },
      required: ["action", "result"]
    }

  alias Lux.Integrations.Twitter.Analytics

  def handler(input, _context) do
    action = Map.get(input, :action) || Map.get(input, "action", "run_full_audit")
    payload = Map.get(input, :payload) || Map.get(input, "payload", %{})

    case execute_action(action, payload) do
      {:ok, result} ->
        {:ok, %{action: action, result: result}}

      {:error, reason} ->
        {:error, "TwitterAnalyticsPrism error on '#{action}': #{inspect(reason)}"}
    end
  end

  defp execute_action("track_engagement", payload) do
    tweets = Map.get(payload, :tweets, Map.get(payload, "tweets", []))
    {:ok, Analytics.aggregate_engagement(tweets)}
  end

  defp execute_action("track_follower_growth", payload) do
    snapshots = Map.get(payload, :snapshots, Map.get(payload, "snapshots", []))
    {:ok, Analytics.analyze_follower_growth(snapshots)}
  end

  defp execute_action("analyze_hashtags", payload) do
    tweets = Map.get(payload, :tweets, Map.get(payload, "tweets", []))
    {:ok, %{hashtags: Analytics.analyze_hashtags(tweets)}}
  end

  defp execute_action("analyze_sentiment", payload) do
    cond do
      text = Map.get(payload, :text, Map.get(payload, "text")) ->
        {:ok, Analytics.analyze_sentiment(text)}

      mentions = Map.get(payload, :mentions, Map.get(payload, "mentions")) ->
        {:ok, Analytics.analyze_mentions_sentiment(mentions)}

      true ->
        {:ok, Analytics.analyze_mentions_sentiment([])}
    end
  end

  defp execute_action("check_alerts", payload) do
    data = Map.get(payload, :analytics_data, Map.get(payload, "analytics_data", %{}))
    thresholds = Map.get(payload, :thresholds, Map.get(payload, "thresholds", %{}))
    {:ok, %{alerts: Analytics.check_alerts(data, thresholds)}}
  end

  defp execute_action("generate_report", payload) do
    data = Map.get(payload, :analytics_data, Map.get(payload, "analytics_data", %{}))
    opts = Map.get(payload, :opts, [])
    {:ok, %{report: Analytics.generate_markdown_report(data, opts)}}
  end

  defp execute_action("run_full_audit", payload) do
    tweets = Map.get(payload, :tweets, Map.get(payload, "tweets", []))
    snapshots = Map.get(payload, :snapshots, Map.get(payload, "snapshots", []))
    mentions = Map.get(payload, :mentions, Map.get(payload, "mentions", []))
    thresholds = Map.get(payload, :thresholds, Map.get(payload, "thresholds", %{}))
    report_opts = Map.get(payload, :report_opts, [])

    result = Analytics.run_full_audit(tweets, snapshots, mentions, thresholds, report_opts)
    {:ok, result}
  end

  defp execute_action(unknown, _payload) do
    {:error, "Unknown action: #{unknown}"}
  end
end
