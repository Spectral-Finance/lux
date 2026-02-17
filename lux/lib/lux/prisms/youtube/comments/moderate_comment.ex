defmodule Lux.Integrations.Youtube.Comments.ModerateComment do
  @moduledoc """
  Module for moderating YouTube comments using the YouTube Data API v3.
  """

  require Logger

  @base_url "https://www.googleapis.com/youtube/v3"

  defp api_key() do
    Application.get_env(:lux, :youtube_api_key)
  end

  def moderate_comment(video_id, comment_id, action) do
    url = "#{@base_url}/comments"
    params = [
      id: comment_id,
      part: "snippet",
      action: action,
      key: api_key()
    ]

    case HTTPoison.post(url, [], params: params) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Poison.decode!(body)}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Error moderating YouTube comment: #{reason}")
        {:error, reason}
    end
  end
end

def moderate_comment_prism(video_id, comment_id, action) do
  url = "#{@base_url}/comments"
  params = [
    id: comment_id,
    part: "snippet",
    action: action,
    key: api_key()
  ]

  case HTTPoison.post(url, [], params: params) do
    {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
      {:ok, Poison.decode!(body)}

    {:error, %HTTPoison.Error{reason: reason}} ->
      Logger.error("Error moderating YouTube comment: #{reason}")
      {:error, reason}
  end
end