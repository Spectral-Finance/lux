defmodule Lux.Lenses.YouTube.AnalyticsLens do
  @moduledoc """
  Lens for fetching channel statistics from the YouTube Data API.

  ## Example

  ```
  alias Lux.Lenses.YouTube.AnalyticsLens

  AnalyticsLens.focus(%{
    channel_id: "UC_x5XG1OV2P6uZZ5FSM9Ttw"
  })
  ```
  """

  use Lux.Lens,
    name: "YouTube Analytics API",
    description: "Fetches channel statistics from YouTube",
    url: "https://youtube.googleapis.com/youtube/v3/channels",
    method: :get,
    auth: %{
      type: :custom,
      auth_function: &__MODULE__.add_api_key/1
    },
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "YouTube Channel ID"
        }
      },
      required: ["channel_id"]
    }

  def add_api_key(lens) do
    lens
  end

  def before_focus(params) do
    %{
      part: "statistics",
      id: params.channel_id,
      key: Lux.Config.youtube_api_key()
    }
  end

  @impl true
  def after_focus(%{"items" => [channel | _]}) do
    stats = channel["statistics"] || %{}
    
    {:ok, %{
      views: String.to_integer(Map.get(stats, "viewCount", "0")),
      subscribers: String.to_integer(Map.get(stats, "subscriberCount", "0")),
      videos: String.to_integer(Map.get(stats, "videoCount", "0"))
    }}
  end

  @impl true
  def after_focus(%{"error" => %{"message" => message}}) do
    {:error, message}
  end

  @impl true
  def after_focus(%{"error" => error}) when is_binary(error) do
    {:error, error}
  end

  @impl true
  def after_focus(response) do
    {:error, "Unexpected response format: #{inspect(response)}"}
  end
end
