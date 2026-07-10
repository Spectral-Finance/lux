defmodule Lux.Prisms.Twitter.CreateTweetTest do
  use ExUnit.Case, async: true
  
  alias Lux.Prisms.Twitter.CreateTweet

  setup do
    Application.put_env(:lux, :api_keys, twitter_bearer_token: "test_token")
    on_exit(fn -> Application.delete_env(:lux, :api_keys) end)
    :ok
  end

  test "handler/2 creates a tweet successfully" do
    Req.Test.stub(CreateTweetTestPlug, fn conn ->
      Req.Test.json(conn, %{"data" => %{"id" => "12345", "text" => "Hello World"}})
    end)

    input = %{"text" => "Hello World"}
    
    Application.put_env(:lux, Lux.Integrations.Twitter.Client, plug: CreateTweetTestPlug)
    on_exit(fn -> Application.delete_env(:lux, Lux.Integrations.Twitter.Client) end)

    assert {:ok, response} = CreateTweet.handler(input, nil)
    assert response["data"]["id"] == "12345"
  end
end
