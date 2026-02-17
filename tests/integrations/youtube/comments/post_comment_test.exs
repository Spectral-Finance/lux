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
    url = "#{@base_url}/comments"
    params = [
      part: "snippet",
      parentId: video_id,
      snippet: %{
        topLevelComment: %{
          snippet: %{
            textDisplay: comment_text
          }
        }
      },
      key: api_key()
    ]

    case HTTPoison.post(url, Poison.encode!(params), [{"Content-Type", "application/json"}]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Poison.decode!(body)}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Error posting YouTube comment: #{reason}")
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

  test "post_comment/2 with valid data" do
    video_id = "dQw4w9WgXcQ"
    comment_text = "This is a test comment."

    response = Comments.post_comment(video_id, comment_text)

    assert {:ok, %{"id" => _}} = response
  end

  test "post_comment/2 with invalid data" do
    video_id = "invalid_video_id"
    comment_text = "This is an invalid comment."

    response = Comments.post_comment(video_id, comment_text)

    assert {:error, reason} = response
    assert reason == "Invalid video ID"
  end
end