defmodule Lux.Lenses.Youtube.Analytics.ChannelAuditLens do
  @moduledoc """
  Lens for accessing channel audit data from YouTube Analytics.
  """

  import Enum
alias Lux.{Client, Error}

  def get(channel_id) do
    Client.get("/youtube/analytics/v1/reports", %{
      ids: "channel==#{channel_id}",
      metrics: "views,subscribersGained",
      dimensions: "day"
    })
    |> handle_response()
  end

  defp handle_response({:ok, %{"items" => items}}) do
    {:ok, Enum.map(items, fn item -> Map.take(item, ["id", "metrics"]) end)}
  end

  defp handle_response({:error, error}) do
    {:error, Error.new("Failed to fetch channel analytics", error)}
  end
end

defmodule Lux.Tests.ChannelAuditTest do
  use ExUnit.Case
  alias Lux.Lenses.Youtube.Analytics.ChannelAnalyticsLens

  test "get/1 returns channel analytics data" do
    channel_id = "UC_x5XG1OV2P6uZZ5FSM9Ttw"
    response = ChannelAnalyticsLens.get(channel_id)
    assert {:ok, _analytics_data} = response
  end

  test "get/1 handles errors" do
    Client.mock(:get, fn _, _ -> {:error, %HTTPoison.Error{reason: :nxdomain}} end)

    channel_id = "UC_x5XG1OV2P6uZZ5FSM9Ttw"
    response = ChannelAnalyticsLens.get(channel_id)
    assert {:error, %Error{message: "Failed to fetch channel analytics", reason: _}} = response
  end
end

test "get/1 generates report" do
  channel_id = "UC_x5XG1OV2P6uZZ5FSM9Ttw"
  response = ChannelAnalyticsLens.get(channel_id)
  assert {:ok, analytics_data} = response
  assert Enum.any?(analytics_data, fn item -> Map.has_key?(item, "metrics") end)
end