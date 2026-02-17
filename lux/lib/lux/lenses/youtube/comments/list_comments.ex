defmodule Lux.Lenses.Youtube.Comments.ListComments do
  @moduledoc """
  Lens for listing comments on YouTube videos.
  """

  require Logger

  @base_url "https://www.googleapis.com/youtube/v3"

  defp api_key() do
    Application.get_env(:lux, :youtube_api_key)
  end

  def list_comments(video_id) do
    """
    Lists comments for a given YouTube video.

    ## Parameters

      - `video_id`: The ID of the YouTube video to fetch comments for.

    ## Returns

      - `{:ok, comments}` if successful, where `comments` is a list of comment objects.
      - `{:error, reason}` if an error occurs, where `reason` is the error message.
    """

    url = "#{@base_url}/comments"
    params = [
      part: "snippet",
      videoId: video_id,
      key: api_key()
    ]

    case HTTPoison.get(url, [], params: params) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Poison.decode!(body)}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Error fetching YouTube comments: #{reason}")
        {:error, reason}
    end
  end
end