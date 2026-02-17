defmodule Lux.Lenses.Youtube.GrowthPredictionPrism do
  @moduledoc """
  Lens for accessing growth prediction data from YouTube Analytics.
  """

  import Enum
import Jason # Add this line for JSON parsing if needed
alias Lux.{Client, Error}

  def predict_growth(channel_id) do
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
    {:error, Error.new("Failed to fetch growth prediction data", error)}
  end
end

def initialize() do
  # Initialization logic here if needed
  :ok
end