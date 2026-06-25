defmodule Lux.Prisms.Twitter.EditTweet do
  @moduledoc """
  A prism for editing existing tweets on Twitter.

  ## Examples

      iex> EditTweet.handler(%{tweet_id: "123", text: "Updated text"}, %{name: "Agent"})
      {:ok, %{id: "123", text: "Updated text"}}
  """

  use Lux.Prism,
    name: "Edit Tweet",
    description: "Edits an existing tweet on Twitter",
    input_schema: %{
      type: :object,
      properties: %{
        tweet_id: %{
          type: :string,
          description: "The ID of the tweet to edit"
        },
        text: %{
          type: :string,
          description: "The new text content (max 280 characters)",
          minLength: 1,
          maxLength: 280
        }
      },
      required: ["tweet_id", "text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string, description: "The ID of the edited tweet"},
        text: %{type: :string, description: "The updated text"}
      },
      required: ["id", "text"]
    }

  alias Lux.Integrations.Twitter.Client
  require Logger

  @doc """
  Handles editing a tweet.

  Returns {:ok, %{id, text}} on success.
  """
  def handler(params, agent) do
    with {:ok, tweet_id} <- validate_param(params, :tweet_id),
         {:ok, text} <- validate_param(params, :text),
         {:ok, _} <- validate_tweet_length(text) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} editing tweet #{tweet_id}")

      case Client.request(:put, "/tweets/#{tweet_id}", %{json: %{text: text}}) do
        {:ok, %{"data" => tweet_data}} ->
          Logger.info("Successfully edited tweet #{tweet_id}")
          {:ok, Map.take(tweet_data, ["id", "text"])}

        {:error, {status, %{"errors" => errors}}} when is_list(errors) ->
          error_msg = List.first(errors) |> Map.get("message", "Unknown error")
          Logger.error("Failed to edit tweet: #{error_msg}")
          {:error, {status, error_msg}}

        {:error, error} ->
          Logger.error("Failed to edit tweet: #{inspect(error)}")
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

  defp validate_tweet_length(text) when byte_size(text) <= 280, do: {:ok, text}
  defp validate_tweet_length(text), do: {:error, "Tweet text exceeds 280 character limit"}
end
