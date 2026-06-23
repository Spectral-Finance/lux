defmodule Lux.Lenses.YouTube.CommentsLens do
  use Lux.Lens,
    name: "YouTube Comments",
    description: "Fetches comment threads from a YouTube video",
    url: "https://youtube.googleapis.com/youtube/v3/commentThreads",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        videoId: %{type: :string, description: "The ID of the video"},
        pageToken: %{type: :string, description: "Token for pagination"},
        part: %{type: :string, description: "Parts to fetch"}
      },
      required: ["videoId"]
    }

  def before_focus(params) do
    # Add API key from config
    api_key = Lux.Config.youtube_api_key()
    params
    |> Map.put_new(:part, "snippet")
    |> Map.put(:key, api_key)
  end

  def after_focus(body) do
    {:ok, body}
  end
end
