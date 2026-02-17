defmodule Lux.Lenses.Youtube.Analytics.ChannelAnalyticsLensTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Youtube.Analytics.ChannelAnalyticsLens

  test "get/1 returns channel analytics data" do
    channel_id = "UC_x5XG1OV2P6uZZ5FSM9Ttw"
    expected_response = %{
      items: [
        %{id: "day1", metrics: %{views: 100, subscribersGained: 5}},
        %{id: "day2", metrics: %{views: 150, subscribersGained: 3}}
      ]
    }

    Client = Mox.stub_for(Lux.Client)
    Mox.expect(Client, :get, fn "/youtube/analytics/v1/reports", params ->
      assert params == %{
        ids: "channel==#{channel_id}",
        metrics: "views,subscribersGained",
        dimensions: "day"
      }
      {:ok, expected_response}
    end)

    response = ChannelAnalyticsLens.get(channel_id)
    assert response == {:ok, expected_response.items}
  end

  test "get/1 handles errors" do
    channel_id = "UC_x5XG1OV2P6uZZ5FSM9Ttw"
    error = %HTTPoison.Error{reason: :nxdomain}

    Client = Mox.stub_for(Lux.Client)
    Mox.expect(Client, :get, fn "/youtube/analytics/v1/reports", _params ->
      {:error, error}
    end)

    response = ChannelAnalyticsLens.get(channel_id)
    assert response == {:error, Error.new("Failed to fetch channel analytics", error)}
  end
end

test "get/1 with custom dimensions" do
  channel_id = "UC_x5XG1OV2P6uZZ5FSM9Ttw"
  expected_response = %{
    items: [
      %{id: "day1", metrics: %{views: 100, subscribersGained: 5}},
      %{id: "day2", metrics: %{views: 150, subscribersGained: 3}}
    ]
  }

  custom_dimensions = "country"

  Client = Mox.stub_for(Lux.Client)
  Mox.expect(Client, :get, fn "/youtube/analytics/v1/reports", params ->
    assert params == %{
      ids: "channel==#{channel_id}",
      metrics: "views,subscribersGained",
      dimensions: custom_dimensions
    }
    {:ok, expected_response}
  end)

  response = ChannelAnalyticsLens.get(channel_id, custom_dimensions)
  assert response == {:ok, expected_response.items}
end