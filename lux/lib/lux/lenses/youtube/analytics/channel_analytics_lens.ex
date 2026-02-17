defmodule Lux.Lenses.Youtube.Analytics.ChannelAnalyticsLens do
  @moduledoc """
  Lens for accessing channel analytics data from YouTube Analytics.
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

def initialize() do
  # Initialize any necessary resources or configurations here
  :ok
end