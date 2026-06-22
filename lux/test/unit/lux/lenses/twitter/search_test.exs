defmodule Lux.Lenses.Twitter.SearchTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Twitter.Search

  describe "spec/0" do
    test "returns the correct specification" do
      spec = Search.view()
      assert spec.name == "Twitter Search"
      assert spec.description =~ "recent tweets"
      assert Map.has_key?(spec.schema.properties, :query)
      assert "query" in spec.schema.required
    end
  end

  describe "before_focus/1" do
    test "assigns default pagination parameters" do
      params = %{"query" => "crypto"}
      updated = Search.before_focus(params)
      assert updated["max_results"] == 10
      assert updated["tweet.fields"] == "created_at,public_metrics,author_id"
    end
  end

  describe "after_focus/1" do
    test "unwraps data payload" do
      response = %{"data" => [%{"id" => "1", "text" => "hello"}]}
      assert {:ok, [%{"id" => "1", "text" => "hello"}]} = Search.after_focus(response)
    end
  end
end
