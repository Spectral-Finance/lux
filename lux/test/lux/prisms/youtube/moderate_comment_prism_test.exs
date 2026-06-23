defmodule Lux.Prisms.YouTube.ModerateCommentPrismTest do
  use ExUnit.Case, async: false
  alias Lux.Prisms.YouTube.ModerateCommentPrism
  import Mock

  test "calls moderation API when dry_run is false" do
    mock_response = %{status: 204, body: ""}

    with_mock Req, [:passthrough], [request: fn _req, _opts -> {:ok, mock_response} end] do
      assert {:ok, _} = ModerateCommentPrism.run(%{id: "comment123", moderationStatus: "rejected", dry_run: false})
      assert called Req.request(:_, :_)
    end
  end

  test "skips API call when dry_run is true" do
    with_mock Req, [:passthrough], [request: fn _req, _opts -> {:ok, %{status: 204, body: ""}} end] do
      assert {:ok, %{dry_run: true}} = ModerateCommentPrism.run(%{id: "comment123", moderationStatus: "rejected", dry_run: true})
      refute called Req.request(:_, :_)
    end
  end
end
