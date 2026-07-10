defmodule Lux.Prisms.Twitter.DeleteTweetTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Twitter.DeleteTweet

  setup do
    Application.put_env(:lux, :env, :test)
    Application.put_env(:lux, :twitter_bearer_token, "test_token")
    :ok
  end

  test "deletes a tweet successfully" do
    Req.Test.stub(Lux.Integrations.Twitter, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/2/tweets/123"
      
      Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"data" => %{"deleted" => true}}))
    end)

    assert {:ok, %{"deleted" => true}} = 
      DeleteTweet.handler(%{"tweet_id" => "123"}, %{})
  end

  test "handles error response" do
    Req.Test.stub(Lux.Integrations.Twitter, fn conn ->
      Plug.Conn.send_resp(conn, 404, Jason.encode!(%{"errors" => ["Not Found"]}))
    end)

    assert {:error, msg} = DeleteTweet.handler(%{"tweet_id" => "999"}, %{})
    assert msg =~ "Twitter API error"
  end
end
