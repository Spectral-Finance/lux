defmodule Lux.Integrations.Youtube.Comments do
  @moduledoc """
  Module for interacting with YouTube comments.
  """

  require Logger

  @base_url "https://www.googleapis.com/youtube/v3"

  defp api_key() do
    Application.get_env(:lux, :youtube_api_key)
  end

  def post_comment(video_id, comment_text) do
    """
    Posts a comment on a YouTube video.

    ## Parameters

      - `video_id`: The ID of the YouTube video to which the comment will be posted.
      - `comment_text`: The text of the comment to be posted.

    ## Returns

      - `{:ok, comment}` if the comment is successfully posted.
      - `{:error, reason}` if an error occurs during the posting process.
    """
    url = "#{@base_url}/comments"
    headers = [{"Authorization", "Bearer #{api_key()}"}]
    body = Jason.encode!(%{
      snippet: %{
        videoId: video_id,
        topLevelComment: %{
          snippet: %{
            textDisplay: comment_text
          }
        }
      }
    })

    case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Poison.decode!(body)}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Error posting YouTube comment: #{reason}")
        {:error, reason}
    end
  end

  def apply_prism(comment) do
    # Apply prism logic here
    comment
  end
end