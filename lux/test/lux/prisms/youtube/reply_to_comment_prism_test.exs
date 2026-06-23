defmodule Lux.Prisms.YouTube.ReplyToCommentPrismTest do
  use ExUnit.Case, async: false
  alias Lux.Prisms.YouTube.ReplyToCommentPrism
  import Mock

  test "replies to comment successfully" do
    mock_response = %{
      status: 200,
      body: %{
        "id" => "reply123",
        "snippet" => %{"textDisplay" => "Thanks for the feedback!"}
      }
    }

    with_mock Req, [:passthrough], [request: fn _req, _opts -> {:ok, mock_response} end] do
      assert {:ok, result} = ReplyToCommentPrism.run(%{parentId: "comment123", textOriginal: "Thanks for the feedback!"})
      assert result["id"] == "reply123"
      assert called Req.request(:_, :_)
    end
  end
end
