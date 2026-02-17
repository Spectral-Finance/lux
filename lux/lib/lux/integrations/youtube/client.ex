defmodule Lux.Integrations.Youtube.Client do
  @moduledoc """
  Module for interacting with the YouTube Data API v3.

  Functions:
  - `search(query)`: Searches YouTube for videos matching a query.
  - `initialize(api_key)`: Initializes the YouTube API key.
  - `fetch_comments(video_id)`: Fetches comments for a given video ID.
  """

  require Logger

  @base_url "https://www.googleapis.com/youtube/v3"

  defp api_key() do
    Application.get_env(:lux, :youtube_api_key)
  end

  @doc """
  Searches YouTube for videos matching the given query.

  ## Parameters
  - `query`: The search query string.

  ## Returns
  - `{:ok, results}`: A tuple with the search results if successful.
  - `{:error, reason}`: An error tuple with the reason if an error occurs.
  """
  def search(query) do
    url = "#{@base_url}/search"
    params = [
      q: query,
      part: "snippet",
      key: api_key()
    ]

    case HTTPoison.get(url, [], params: params) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Poison.decode!(body)}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Error fetching YouTube search results: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Initializes the YouTube API key.

  ## Parameters
  - `api_key`: The API key to use for YouTube requests.
  """
  def initialize(api_key) do
    Application.put_env(:lux, :youtube_api_key, api_key)
  end

  @doc """
  Fetches comments for a given video ID.

  ## Parameters
  - `video_id`: The ID of the video for which to fetch comments.

  ## Returns
  - `{:ok, results}`: A tuple with the comment results if successful.
  - `{:error, reason}`: An error tuple with the reason if an error occurs.
  """
  def fetch_comments(video_id) do
    url = "#{@base_url}/commentThreads"
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