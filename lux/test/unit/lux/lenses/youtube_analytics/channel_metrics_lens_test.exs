defmodule Lux.Lenses.YoutubeAnalytics.ChannelMetricsLensTest do
  use ExUnit.Case, async: true
  doctest Lux.Lenses.YoutubeAnalytics.ChannelMetricsLens

  describe "focus/1" do
    test "has correct lens metadata" do
      assert Lux.Lenses.YoutubeAnalytics.ChannelMetricsLens.__meta__(:name) == "YouTube Channel Metrics"
      assert Lux.Lenses.YoutubeAnalytics.ChannelMetricsLens.__meta__(:method) == :get
    end

    test "schema has required fields" do
      schema = Lux.Lenses.YoutubeAnalytics.ChannelMetricsLens.__schema__()
      assert schema[:properties][:channel_id] != nil
    end

    test "output schema defines expected fields" do
      output = Lux.Lenses.YoutubeAnalytics.ChannelMetricsLens.__output_schema__()
      assert output[:properties][:subscriber_count] != nil
      assert output[:properties][:view_count] != nil
      assert output[:properties][:video_count] != nil
      assert output[:properties][:title] != nil
    end

    test "returns error for missing channel_id and username" do
      assert {:error, _} = Lux.Lenses.YoutubeAnalytics.ChannelMetricsLens.focus(%{})
    end
  end
end
