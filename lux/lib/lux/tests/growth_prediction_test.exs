defmodule Lux.Lenses.Youtube.Analytics.GrowthPredictionLens do
  @moduledoc """
  Lens for accessing growth prediction data from YouTube Analytics.
  """

  import Enum
alias Lux.{Client, Error}

  def get(channel_id) do
    Client.get("/youtube/analytics/v1/reports", %{
      ids: "channel==#{channel_id}",
      metrics: "estimatedSubscribers",
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

defmodule Lux.Lenses.Youtube.Analytics.GrowthPredictionLensTest do
  use ExUnit.Case, async: true
  alias Lux.Lenses.Youtube.Analytics.GrowthPredictionLens

  test "get/1 returns growth prediction data for a channel" do
    channel_id = "UC_x5XG1OV2P6uZZ5FSM9Ttw"
    expected_response = [
      %{"id" => channel_id, "metrics" => %{"estimatedSubscribers" => 1000}},
      %{"id" => channel_id, "metrics" => %{"estimatedSubscribers" => 1200}}
    ]

    Client
    |> expect(:get, fn _url, _params -> {:ok, %{"items" => expected_response}} end)

    assert GrowthPredictionLens.get(channel_id) == {:ok, expected_response}
  end

  test "get/1 returns an error when fetching growth prediction data fails" do
    channel_id = "UC_x5XG1OV2P6uZZ5FSM9Ttw"
    error = %HTTPoison.Error{reason: :nxdomain}

    Client
    |> expect(:get, fn _url, _params -> {:error, error} end)

    assert GrowthPredictionLens.get(channel_id) == {:error, Error.new("Failed to fetch growth prediction data", error)}
  end
end