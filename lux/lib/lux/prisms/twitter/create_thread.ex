defmodule Lux.Prisms.Twitter.CreateThread do
  @moduledoc """
  A prism for creating a thread of tweets via the Twitter API v2.
  """
  use Lux.Prism,
    name: "Create Thread",
    description: "Posts a sequence of tweets as a thread on behalf of the authenticated user.",
    input_schema: %{
      type: :object,
      properties: %{
        tweets: %{
          type: :array,
          items: %{type: :string},
          description: "A list of strings, each representing a tweet in the thread"
        }
      },
      required: ["tweets"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(input, _ctx) do
    tweets = Map.get(input, "tweets") || Map.get(input, :tweets)
    
    if is_list(tweets) and length(tweets) > 0 do
      Client.create_thread(tweets)
    else
      {:error, "Thread must contain at least one tweet"}
    end
  end
end
