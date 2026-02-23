defmodule Lux.Lenses.Twitter.Analytics.GetMentionsTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Twitter.Analytics.GetMentions

  describe "after_focus/1" do
    test "transforms mentions with metrics" do
      response = %{
        "data" => [
          %{
            "id" => "111",
            "text" => "Great work @testuser!",
            "author_id" => "222",
            "created_at" => "2024-01-01T00:00:00.000Z",
            "public_metrics" => %{"like_count" => 5, "retweet_count" => 2, "reply_count" => 1}
          },
          %{
            "id" => "333",
            "text" => "Interesting point @testuser",
            "author_id" => "444",
            "created_at" => "2024-01-01T01:00:00.000Z",
            "public_metrics" => %{"like_count" => 1, "retweet_count" => 0, "reply_count" => 0}
          }
        ],
        "meta" => %{"result_count" => 2, "newest_id" => "333", "oldest_id" => "111"}
      }

      assert {:ok, result} = GetMentions.after_focus(response)
      assert result.count == 2
      assert length(result.mentions) == 2
      assert result.result_count == 2
      first = List.first(result.mentions)
      assert first.id == "111"
      assert first.metrics.like_count == 5
    end

    test "handles empty mention results" do
      response = %{"meta" => %{"result_count" => 0}}
      assert {:ok, %{mentions: [], count: 0}} = GetMentions.after_focus(response)
    end

    test "returns error for API errors" do
      response = %{"errors" => [%{"title" => "Forbidden", "detail" => "Not authorized"}]}
      assert {:error, %{title: "Forbidden"}} = GetMentions.after_focus(response)
    end
  end
end
