defmodule Lux.Lenses.Twitter.TweetLensTest do
  use ExUnit.Case, async: true
  alias Lux.Lenses.Twitter.TweetLens
  alias Lux.Lens.Twitter.Tweet

  test "returns a list of Tweet structs on success" do
    response = %{
      "data" => [
        %{
          "id" => "12345",
          "text" => "Hello world",
          "author_id" => "999",
          "created_at" => "2023-01-01T12:00:00.000Z",
          "public_metrics" => %{"retweet_count" => 10, "reply_count" => 5, "like_count" => 20, "quote_count" => 1}
        },
        %{
          "id" => "67890",
          "text" => "Another tweet",
          "author_id" => "888"
        }
      ]
    }

    assert {:ok, tweets} = TweetLens.after_focus(response)
    assert length(tweets) == 2

    tweet1 = Enum.at(tweets, 0)
    assert %Tweet{} = tweet1
    assert tweet1.id == "12345"
    assert tweet1.text == "Hello world"
    assert tweet1.author_id == "999"
    assert tweet1.created_at == "2023-01-01T12:00:00.000Z"
    assert tweet1.public_metrics == %{"retweet_count" => 10, "reply_count" => 5, "like_count" => 20, "quote_count" => 1}

    tweet2 = Enum.at(tweets, 1)
    assert %Tweet{} = tweet2
    assert tweet2.id == "67890"
    assert tweet2.text == "Another tweet"
    assert tweet2.author_id == "888"
    assert tweet2.created_at == nil
  end

  test "returns error on failure" do
    assert {:error, "Not Found"} = TweetLens.after_focus(%{"errors" => [%{"detail" => "Not Found"}]})
  end
end
