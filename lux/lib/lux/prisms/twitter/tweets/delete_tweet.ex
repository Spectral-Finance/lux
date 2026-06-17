defmodule Lux.Prisms.Twitter.Tweets.DeleteTweet do
  @moduledoc """
  A prism for deleting tweets via Twitter API v2.

  ## Examples

      iex> DeleteTweet.handler(%{tweet_id: "1234567890"}, %{name: "Agent"})
      {:ok, %{deleted: true, tweet_id: "1234567890"}}
  """

  use Lux.Prism,
    name: "Delete Tweet",
    description: "Deletes a tweet from Twitter",
    input_schema: %{
      type: :object,
      properties: %{
        tweet_id: %{
          type: :string,
          description: "The ID of the tweet to delete"
        }
      },
      required: ["tweet_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        deleted: %{
          type: :boolean,
          description: "Whether the tweet was successfully deleted"
        },
        tweet_id: %{
          type: :string,
          description: "The ID of the deleted tweet"
        }
      },
      required: ["deleted"]
    }

  alias Lux.Integrations.Twitter.Client
  require Logger

  @doc """
  Handles the request to delete a tweet.
  """
  def handler(params, agent) do
    with {:ok, tweet_id} <- validate_param(params, :tweet_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} deleting tweet #{tweet_id}")

      case Client.request(:delete, "/tweets/#{tweet_id}") do
        {:ok, %{"data" => %{"deleted" => true}}} ->
          Logger.info("Successfully deleted tweet #{tweet_id}")
          {:ok, %{deleted: true, tweet_id: tweet_id}}

        {:ok, _response} ->
          # Twitter API may return different formats
          Logger.info("Delete request completed for tweet #{tweet_id}")
          {:ok, %{deleted: true, tweet_id: tweet_id}}

        {:error, {status, message}} ->
          Logger.error("Failed to delete tweet #{tweet_id}: #{status} - #{inspect(message)}")
          {:error, {status, message}}

        {:error, error} ->
          Logger.error("Failed to delete tweet #{tweet_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
