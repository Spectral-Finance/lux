defmodule Lux.Company.YouTubeIntelligenceCompany do
  @moduledoc """
  Orchestrates the YouTube Content Intelligence workflow.
  """
  use Lux.Company

  def setup do
    %{
      name: "YouTube Intelligence Systems",
      description: "A company dedicated to end-to-end YouTube channel optimization.",
      agents: [
        Lux.Agent.YouTubeDataScout,
        Lux.Agent.YouTubeCreativeOptimizer
      ],
      workflows: [:optimize_new_video, :analyze_channel_health]
    }
  end

  def run_optimization_workflow(topic, historical_data) do
    # 1. Predict optimal posting time and performance
    prediction = Lux.Agent.YouTubeDataScout.predict_performance(%{topic: topic, data: historical_data})
    
    # 2. Generate optimized metadata
    metadata = Lux.Agent.YouTubeCreativeOptimizer.generate_metadata(%{topic: topic, keywords: prediction.suggested_keywords})
    
    %{
      prediction: prediction,
      metadata: metadata,
      status: :success
    }
  end
end
