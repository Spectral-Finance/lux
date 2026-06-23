defmodule Lux.Lenses.YouTube.CommunityPostsLensTest do
  use ExUnit.Case, async: false
  alias Lux.Lenses.YouTube.CommunityPostsLens
  import Mock

  test "fetches channel activity" do
    mock_response = %{
      status: 200,
      body: %{
        "items" => [
          %{"id" => "1", "snippet" => %{"type" => "post"}}
        ]
      }
    }

    with_mock Req, [:passthrough], [request: fn _req, _opts -> {:ok, mock_response} end] do
      assert {:ok, body} = CommunityPostsLens.focus(%{channelId: "chan123"})
      assert length(body["items"]) == 1
    end
  end
end
