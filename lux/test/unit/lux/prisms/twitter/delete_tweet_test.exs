defmodule Lux.Prisms.Twitter.DeleteTweetTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Twitter.DeleteTweet

  describe "spec/0" do
    test "returns the correct specification" do
      spec = DeleteTweet.view()
      assert spec.name == "Delete Tweet"
      assert Map.has_key?(spec.input_schema.properties, :tweet_id)
    end
  end
end
