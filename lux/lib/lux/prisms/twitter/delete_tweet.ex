defmodule Lux.Prisms.Twitter.DeleteTweet do
  @moduledoc """
  A prism for deleting tweets on Twitter.

  ## Examples

      iex> DeleteTweet.handler(%{tweet_id: "123456789"}, %{name: "Agent"})
      {:ok, %{deleted: true, tweet_id: "123456789"}}
  """

  use Lux.Prism,
    name: "Delete Tweet",
    description: "Deletes a tweet on Twitter",
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
        deleted: %{type: :boolean, description: "Whether the tweet was deleted"},
        tweet_id: %{type: :string, description: "The ID of the deleted tweet"}
      },
      required: ["deleted", "tweet_id"]
    }

  alias Lux.Integrations.Twitter.Client
  require Logger

  @doc """
  Handles deleting a tweet.

  Returns {:ok, %{deleted: true, tweet_id: id}} on success.
  """
  def handler(params, agent) do
    with {:ok, tweet_id} <- validate_param(params, :tweet_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} deleting tweet #{tweet_id}")

      case Client.request(:delete, "/tweets/#{tweet_id}") do
        {:ok, %{"data" => %{"deleted" => true}}} ->
          Logger.info("Successfully deleted tweet #{tweet_id}")
          {:ok, %{deleted: true, tweet_id: tweet_id}}

        {:ok, %{"data" => %{"deleted" => false}}} ->
          {:error, "Failed to delete tweet #{tweet_id}"}

        {:error, {status, %{"errors" => errors}}} when is_list(errors) ->
          error_msg = List.first(errors) |> Map.get("message", "Unknown error")
          Logger.error("Failed to delete tweet: #{error_msg}")
          {:error, {status, error_msg}}

        {:error, error} ->
          Logger.error("Failed to delete tweet: #{inspect(error)}")
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
