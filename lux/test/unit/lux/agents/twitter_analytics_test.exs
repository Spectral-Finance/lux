defmodule Lux.Agents.TwitterAnalyticsTest do
  use ExUnit.Case, async: false

  import Mock
  alias Lux.Agents.TwitterAnalytics

  setup do
    Application.put_env(:lux, :api_keys, [
      openai: "TEST_OPENAI_KEY"
    ])
    :ok
  end

  describe "generate_report/2" do
    test "generates a report successfully" do
      metrics_data = %{
        tweet_metrics: %{"like_count" => 150, "retweet_count" => 20},
        follower_metrics: %{"followers_count" => 5000, "following_count" => 200},
        sentiment: %{"sentiment" => "positive", "confidence" => 0.9}
      }

      mock_response = %{
        "summary" => "Great performance.",
        "follower_growth_status" => "Healthy",
        "engagement_rate" => 3.5,
        "sentiment_overview" => "Mostly positive",
        "alerts" => []
      }

      # We will mock the LLM completion to return our mock JSON
      with_mock Lux.LLM.OpenAI, [
        chat_completion: fn(_config, _messages, _opts) ->
          {:ok, %{"choices" => [%{"message" => %{"content" => Jason.encode!(mock_response)}}]}}
        end
      ] do
        assert {:ok, report} = TwitterAnalytics.generate_report(%TwitterAnalytics{}, metrics_data)
        assert report.summary == "Great performance."
        assert report.engagement_rate == 3.5
        assert report.alerts == []
      end
    end
  end
end
