defmodule Lux.Prisms.YouTube.YouTubeVideoPrismTest do
  use UnitCase, async: true
  alias Lux.Prisms.YouTube.YouTubeVideoPrism

  @moduletag :unit

  setup do
    System.put_env("YOUTUBE_API_KEY", "test_api_key")
    :ok
  end

  test "list videos returns success" do
    Req.Test.stub(YouTubeVideoPrism, fn conn ->
      Req.Test.json(conn, %{
        "items" => [%{
          "id" => "abc123",
          "snippet" => %{"title" => "Test Video", "description" => "Test"},
          "statistics" => %{"viewCount" => "1000", "likeCount" => "50"}
        }],
        "pageInfo" => %{"totalResults" => 1}
      })
    end)
    {:ok, result} = YouTubeVideoPrism.handler(%{action: "list"}, %{})
    assert result.status == "success"
    assert length(result.videos) == 1
  end

  test "get video returns video data" do
    Req.Test.stub(YouTubeVideoPrism, fn conn ->
      Req.Test.json(conn, %{
        "items" => [%{
          "id" => "abc123",
          "snippet" => %{"title" => "Test Video", "description" => "Test"},
          "statistics" => %{"viewCount" => "1000", "likeCount" => "50"}
        }]
      })
    end)
    {:ok, result} = YouTubeVideoPrism.handler(%{action: "get", video_id: "abc123"}, %{})
    assert result.status == "success"
    assert result.video.id == "abc123"
  end

  test "delete video returns success" do
    Req.Test.stub(YouTubeVideoPrism, fn conn ->
      conn |> Plug.Conn.send_resp(204, "")
    end)
    {:ok, result} = YouTubeVideoPrism.handler(%{action: "delete", video_id: "abc123"}, %{})
    assert result.status == "success"
  end

  test "missing api key returns error" do
    System.delete_env("YOUTUBE_API_KEY")
    result = YouTubeVideoPrism.handler(%{action: "list"}, %{})
    assert {:error, _} = result
  end
end
