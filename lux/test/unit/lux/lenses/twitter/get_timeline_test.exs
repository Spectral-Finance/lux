defmodule Lux.Lenses.Twitter.GetTimelineTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Twitter.GetTimeline

  describe "spec/0" do
    test "returns the correct specification" do
      spec = GetTimeline.view()
      assert spec.name == "Twitter Timeline Reader"
      assert spec.description =~ "timeline"
      assert Map.has_key?(spec.schema.properties, :user_id)
      assert "user_id" in spec.schema.required
    end
  end

  describe "before_focus/1" do
    test "assigns default pagination parameters" do
      params = %{"user_id" => "123"}
      updated = GetTimeline.before_focus(params)
      assert updated["max_results"] == 10
      assert updated["tweet.fields"] == "created_at,public_metrics,author_id"
    end
  end

  describe "after_focus/1" do
    test "unwraps data payload" do
      response = %{"data" => [%{"id" => "1", "text" => "hello"}]}
      assert {:ok, [%{"id" => "1", "text" => "hello"}]} = GetTimeline.after_focus(response)
    end

    test "handles errors" do
      response = %{"errors" => [%{"message" => "Not found"}]}
      assert {:error, [%{"message" => "Not found"}]} = GetTimeline.after_focus(response)
    end
  end
end
