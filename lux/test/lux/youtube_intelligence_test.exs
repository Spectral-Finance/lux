defmodule Lux.YouTubeIntelligenceTest do
  use ExUnit.Case
  alias Lux.Company.YouTubeIntelligenceCompany
  alias Lux.Agent.YouTubeDataScout

  describe "YouTube Intelligence Workflow" do
    test "full optimization workflow returns prediction and metadata" do
      topic = "Building Multi-Agent Systems with Lux"
      historical_data = [
        %{hour: 10, day_of_week: 1, views: 1000},
        %{hour: 15, day_of_week: 1, views: 4500}
      ]

      # Mocking the Python call for the test environment
      # In a real Lux environment, the bridge would be active
      result = YouTubeIntelligenceCompany.run_optimization_workflow(topic, historical_data)

      assert result.status == :success
      assert Map.has_key?(result, :prediction)
      assert Map.has_key?(result, :metadata)
    end

    test "data scout capability check" do
      setup = YouTubeDataScout.setup()
      assert setup.name == "YouTube Data Scout"
      assert :prediction in setup.capabilities
    end
  end
end
