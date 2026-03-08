defmodule Lux.Prisms.Twitter.Tweets.DeleteTweet do
  @moduledoc """
  Prism for deleting tweets via Twitter API v2.

  ## Examples

      iex> DeleteTweet.handler(%{"tweet_id" => "123456"}, ctx)
      {:ok, %{deleted: true, tweet_id: "123456"}}
  """

  use Lux.Prism,
    name: "Delete Tweet",
    description: "Deletes a tweet by ID",
    input_schema: %{
      type: :object,
      properties: %{
        tweet_id: %{type: :string, description: "ID of the tweet to delete"}
      },
      required: ["tweet_id"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(%{"tweet_id" => tweet_id}, _context) do
    case Client.request(:delete, "/tweets/#{tweet_id}", %{auth_type: :oauth1}) do
      {:ok, %{data: %{"deleted" => true}}} ->
        {:ok, %{deleted: true, tweet_id: tweet_id}}

      {:ok, %{data: data}} ->
        {:ok, %{deleted: data["deleted"] || false, tweet_id: tweet_id}}

      {:error, reason} ->
        {:error, "Failed to delete tweet: #{inspect(reason)}"}
    end
  end
end
