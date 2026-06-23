defmodule Lux.Lenses.YouTube.CommentsLensTest do
  use ExUnit.Case, async: false
  alias Lux.Lenses.YouTube.CommentsLens
  import Mock

  test "fetches comment threads with pagination" do
    mock_response = %{
      status: 200,
      body: %{
        "items" => [
          %{"id" => "1", "snippet" => %{"topLevelComment" => %{"snippet" => %{"textDisplay" => "Test comment"}}}}
        ],
        "nextPageToken" => "token123"
      }
    }

    with_mock Req, [:passthrough], [request: fn _req, _opts -> {:ok, mock_response} end] do
      assert {:ok, body} = CommentsLens.focus(%{videoId: "vid123"})
      assert length(body["items"]) == 1
      assert body["nextPageToken"] == "token123"
    end
  end
end
