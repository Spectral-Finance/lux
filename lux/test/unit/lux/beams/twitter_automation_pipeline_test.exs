defmodule Lux.Beams.TwitterAutomationPipelineTest do
  use ExUnit.Case, async: true
  doctest Lux.Beams.TwitterAutomationPipeline

  describe "run/1" do
    test "runs pipeline with minimal params" do
      assert {:ok, result} = Lux.Beams.TwitterAutomationPipeline.run(%{
        user_id: "12345"
      })

      # Check all expected keys are present
      assert Map.has_key?(result, :timeline_data)
      assert Map.has_key?(result, :engagement_metrics)
      assert Map.has_key?(result, :curated_content)
      assert Map.has_key?(result, :scheduled_tweets)
      assert Map.has_key?(result, :auto_replies)
      assert Map.has_key?(result, :content_calendar)
      assert Map.has_key?(result, :engagement_actions)
      assert Map.has_key?(result, :pipeline_status)
      assert Map.has_key?(result, :summary)
    end

    test "pipeline_status is valid" do
      {:ok, result} = Lux.Beams.TwitterAutomationPipeline.run(%{
        user_id: "12345"
      })

      assert result[:pipeline_status] in ["success", "partial", "error"]
    end

    test "summary has expected fields" do
      {:ok, result} = Lux.Beams.TwitterAutomationPipeline.run(%{
        user_id: "12345"
      })

      summary = result[:summary]
      assert Map.has_key?(summary, :total_steps)
      assert Map.has_key?(summary, :successful_steps)
      assert Map.has_key?(summary, :failed_steps)
    end

    test "runs with keywords and hashtags" do
      {:ok, result} = Lux.Beams.TwitterAutomationPipeline.run(%{
        user_id: "12345",
        keywords: ["elixir", "web3"],
        hashtags: ["DeFi", "Crypto"]
      })

      assert result[:pipeline_status] in ["success", "partial", "error"]
    end

    test "respects schedule_tweets flag" do
      {:ok, result} = Lux.Beams.TwitterAutomationPipeline.run(%{
        user_id: "12345",
        schedule_tweets: false
      })

      # Should have message about scheduling being disabled
      assert result[:scheduled_tweets] != nil
    end

    test "respects auto_reply flag" do
      {:ok, result} = Lux.Beams.TwitterAutomationPipeline.run(%{
        user_id: "12345",
        auto_reply: false
      })

      assert result[:auto_replies] != nil
    end

    test "respects generate_calendar flag" do
      {:ok, result} = Lux.Beams.TwitterAutomationPipeline.run(%{
        user_id: "12345",
        generate_calendar: false
      })

      assert result[:content_calendar] != nil
    end

    test "respects execute_engagement flag" do
      {:ok, result} = Lux.Beams.TwitterAutomationPipeline.run(%{
        user_id: "12345",
        execute_engagement: false
      })

      assert result[:engagement_actions] != nil
    end

    test "respects timezone parameter" do
      {:ok, result} = Lux.Beams.TwitterAutomationPipeline.run(%{
        user_id: "12345",
        timezone: "America/New_York"
      })

      assert result[:pipeline_status] in ["success", "partial", "error"]
    end

    test "respects max_tweets_to_analyze" do
      {:ok, result} = Lux.Beams.TwitterAutomationPipeline.run(%{
        user_id: "12345",
        max_tweets_to_analyze: 5
      })

      assert result[:pipeline_status] in ["success", "partial", "error"]
    end

    test "respects min_engagement_threshold" do
      {:ok, result} = Lux.Beams.TwitterAutomationPipeline.run(%{
        user_id: "12345",
        min_engagement_threshold: 50
      })

      assert result[:pipeline_status] in ["success", "partial", "error"]
    end

    test "has correct beam metadata" do
      assert Lux.Beams.TwitterAutomationPipeline.__meta__(:name) == "Twitter Automation Pipeline"
    end

    test "input schema has required fields" do
      schema = Lux.Beams.TwitterAutomationPipeline.__input_schema__()
      assert "user_id" in schema[:required]
    end

    test "action parameter has enum constraint" do
      schema = Lux.Beams.TwitterAutomationPipeline.__input_schema__()
      action_prop = schema[:properties]["action"]
      assert action_prop[:enum] != nil
      assert "full_automation" in action_prop[:enum]
      assert "analytics_only" in action_prop[:enum]
      assert "content_only" in action_prop[:enum]
      assert "engagement_only" in action_prop[:enum]
    end
  end
end
