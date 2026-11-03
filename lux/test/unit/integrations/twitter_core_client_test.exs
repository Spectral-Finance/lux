defmodule Lux.Integrations.Twitter.CoreClientTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.Twitter.CoreClient

  test "validates tweet length and builds reply payload" do
    assert {:ok, %{text: "Hello Lux", reply: %{in_reply_to_tweet_id: "123"}}} =
             CoreClient.build_tweet_payload("Hello Lux", reply_to_id: "123")

    long_text = String.duplicate("a", 285)
    assert {:error, {:tweet_too_long, 285, 280}} = CoreClient.build_tweet_payload(long_text)
  end
end
