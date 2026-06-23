defmodule Lux.Lenses.YouTube.CommunityPostsLens do
  use Lux.Lens,
    name: "YouTube Community Posts",
    description: "Fetches channel activity / community posts",
    url: "https://youtube.googleapis.com/youtube/v3/activities",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        channelId: %{type: :string, description: "The ID of the channel"},
        pageToken: %{type: :string, description: "Token for pagination"},
        part: %{type: :string, description: "Parts to fetch"}
      },
      required: ["channelId"]
    }

  def before_focus(params) do
    api_key = Lux.Config.youtube_api_key()
    params
    |> Map.put_new(:part, "snippet,contentDetails")
    |> Map.put(:key, api_key)
  end

  def after_focus(body) do
    {:ok, body}
  end
end
