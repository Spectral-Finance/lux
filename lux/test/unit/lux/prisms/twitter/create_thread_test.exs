defmodule Lux.Prisms.Twitter.CreateThreadTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Twitter.CreateThread

  setup do
    Application.put_env(:lux, :env, :test)
    Application.put_env(:lux, :twitter_bearer_token, "test_token")
    :ok
  end

  test "creates a thread successfully" do
    Req.Test.stub(Lux.Integrations.Twitter, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      
      # Mock response based on the text
      case decoded["text"] do
        "First tweet" ->
          Plug.Conn.send_resp(conn, 201, Jason.encode!(%{"data" => %{"id" => "1", "text" => "First tweet"}}))
        "Second tweet" ->
          assert decoded["reply"]["in_reply_to_tweet_id"] == "1"
          Plug.Conn.send_resp(conn, 201, Jason.encode!(%{"data" => %{"id" => "2", "text" => "Second tweet"}}))
        "Third tweet" ->
          assert decoded["reply"]["in_reply_to_tweet_id"] == "2"
          Plug.Conn.send_resp(conn, 201, Jason.encode!(%{"data" => %{"id" => "3", "text" => "Third tweet"}}))
      end
    end)

    assert {:ok, [%{"id" => "1"}, %{"id" => "2"}, %{"id" => "3"}]} = 
      CreateThread.handler(%{"tweets" => ["First tweet", "Second tweet", "Third tweet"]}, %{})
  end

  test "returns error for empty thread" do
    assert {:error, "Cannot create an empty thread"} = 
      CreateThread.handler(%{"tweets" => []}, %{})
  end
end
