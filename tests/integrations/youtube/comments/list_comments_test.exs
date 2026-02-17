defmodule Lux.Integrations.Youtube.Comments do
  @moduledoc """
  Module for interacting with YouTube comments.
  """

  require Logger

  @base_url "https://www.googleapis.com/youtube/v3"

  defp api_key() do
    Application.get_env(:lux, :youtube_api_key)
  end

  def list_comments(video_id) do
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

defmodule Lux.Integrations.Youtube.CommentsTest do
  use ExUnit.Case
  alias Lux.Integrations.Youtube.Comments

  setup_all do
    Application.put_env(:lux, :youtube_api_key, "test_api_key")
    :ok
  end

  test "list_comments/1 returns comments for a given video ID" do
    video_id = "dQw4w9WgXcQ"
    response = Comments.list_comments(video_id)

    assert {:ok, %{"items" => items}} = response
    assert is_list(items)
    Enum.each(items, fn item ->
      assert Map.has_key?(item, "snippet")
      assert Map.has_key?(item, "id")
    end)
  end

  test "list_comments/1 handles errors" do
    Application.put_env(:lux, :youtube_api_key, nil)
    response = Comments.list_comments("dQw4w9WgXcQ")

    assert {:error, _reason} = response
  end
end