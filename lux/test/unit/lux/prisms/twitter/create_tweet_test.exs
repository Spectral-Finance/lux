defmodule Lux.Prisms.Twitter.CreateTweetTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Twitter.CreateTweet

  describe "spec/0" do
    test "returns the correct specification" do
      spec = CreateTweet.view()
      assert spec.name == "Create Tweet"
      assert Map.has_key?(spec.input_schema.properties, :text)
    end
  end
end
