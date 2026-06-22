defmodule Lux.Prisms.Twitter.DeleteTweet do
  @moduledoc """
  A prism that deletes a tweet by ID using the Twitter v2 API.
  """
  use Lux.Prism,
    name: "Delete Tweet",
    description: "Deletes an existing tweet on Twitter.",
    input_schema: %{
      type: :object,
      properties: %{
        tweet_id: %{
          type: :string,
          description: "The ID of the tweet to delete."
        }
      },
      required: ["tweet_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        deleted: %{type: :boolean, description: "Whether the tweet was successfully deleted"}
      }
    }

  alias Lux.Integrations.Twitter.Client

  @impl true
  def handler(params, _context) do
    tweet_id = Map.fetch!(params, "tweet_id")

    case Client.request(:delete, "/tweets/#{tweet_id}") do
      {:ok, %{"deleted" => _} = data} ->
        {:ok, data}

      {:ok, other} ->
        {:ok, other}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
