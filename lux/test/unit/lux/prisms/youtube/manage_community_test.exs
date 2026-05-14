defmodule Lux.Prisms.YouTube.ManageCommunityTest do
  use UnitCase, async: true

  alias Lux.Prisms.YouTube.ManageCommunity

  test "runs the community manager through the prism" do
    assert {:ok, report} =
             ManageCommunity.run(%{
               comments: [
                 %{id: "c1", author: "Mira", text: "Great video. What should I watch next?"}
               ],
               goals: ["increase comments"]
             })

    assert report.comment_management.summary.total_comments == 1
    assert [%{comment_id: "c1", intent: :question}] = report.comment_management.response_queue
  end

  test "exposes schema" do
    prism = ManageCommunity.view()
    assert prism.input_schema.required == ["comments"]
    assert Map.has_key?(prism.output_schema.properties, :moderation_system)
    assert Map.has_key?(prism.output_schema.properties, :community_post_schedule)
  end
end
