defmodule Lux.Lenses.YouTube.AnalyticsLensTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.YouTube.AnalyticsLens

  @moduletag :integration

  setup do
    try do
      Lux.Config.youtube_api_key()
      :ok
    rescue
      _ ->
        {:skip, "YouTube API key not configured"}
    end
  end

  test "fetches analytics for a valid channel ID" do
    {:ok, result} =
      AnalyticsLens.focus(%{
        channel_id: "UC_x5XG1OV2P6uZZ5FSM9Ttw"
      })

    assert %{views: views, subscribers: subs, videos: videos} = result
    assert is_integer(views)
    assert is_integer(subs)
    assert is_integer(videos)
  end

  test "handles invalid channel ID gracefully" do
    result =
      AnalyticsLens.focus(%{
        channel_id: "invalid_channel_id"
      })

    assert {:error, _} = result
  end
end
