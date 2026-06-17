defmodule Lux.Prisms.Twitter.Tweets.QuoteTweet do
  @moduledoc """
  A prism for quote tweeting via Twitter API v2.

  A quote tweet is a tweet that references another tweet, allowing the user
  to add their own commentary.

  ## Examples

      iex> QuoteTweet.handler(%{
      ...>   text: "This is an important point!",
      ...>   quote_tweet_id: "1234567890"
      ...> }, %{name: "Agent"})
      {:ok, %{
        created: true,
        tweet_id: "9876543210",
        text: "This is an important point!",
        quoted_tweet_id: "1234567890"
      }}
  """

  use Lux.Prism,
    name: "Quote Tweet",
    description: "Creates a quote tweet on Twitter",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{
          type: :string,
          description: "The commentary text for the quote tweet",
          minLength: 1,
          maxLength: 280
        },
        quote_tweet_id: %{
          type: :string,
          description: "The ID of the tweet to quote"
        },
        media_ids: %{
          type: :array,
          description: "List of media IDs to attach",
          items: %{type: :string}
        }
      },
      required: ["text", "quote_tweet_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        created: %{
          type: :boolean,
          description: "Whether the quote tweet was successfully created"
        },
        tweet_id: %{
          type: :string,
          description: "The ID of the created quote tweet"
        },
        text: %{
          type: :string,
          description: "The text of the quote tweet"
        },
        quoted_tweet_id: %{
          type: :string,
          description: "The ID of the quoted tweet"
        }
      },
      required: ["created"]
    }

  alias Lux.Integrations.Twitter.Client
  require Logger

  @doc """
  Handles the request to create a quote tweet.
  """
  def handler(params, agent) do
    with {:ok, text} <- validate_param(params, :text),
         {:ok, quote_tweet_id} <- validate_param(params, :quote_tweet_id) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} quote tweeting #{quote_tweet_id}: #{String.slice(text, 0, 50)}...")

      json = %{
        "text" => text,
        "quote_tweet_id" => quote_tweet_id
      }

      json = maybe_add_media(json, params)

      case Client.request(:post, "/tweets", %{json: json}) do
        {:ok, %{"data" => %{"id" => tweet_id, "text" => tweet_text}}} ->
          Logger.info("Successfully created quote tweet #{tweet_id}")
          {:ok, %{created: true, tweet_id: tweet_id, text: tweet_text, quoted_tweet_id: quote_tweet_id}}

        {:ok, %{"data" => data}} ->
          tweet_id = data["id"]
          tweet_text = data["text"]
          Logger.info("Successfully created quote tweet #{tweet_id}")
          {:ok, %{created: true, tweet_id: tweet_id, text: tweet_text, quoted_tweet_id: quote_tweet_id}}

        {:error, {status, message}} ->
          Logger.error("Failed to create quote tweet: #{status} - #{inspect(message)}")
          {:error, {status, message}}

        {:error, error} ->
          Logger.error("Failed to create quote tweet: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp maybe_add_media(json, %{media_ids: ids}) when is_list(ids) and length(ids) > 0 do
    Map.put(json, "media", %{"media_ids" => ids})
  end

  defp maybe_add_media(json, %{"media_ids" => ids}) when is_list(ids) and length(ids) > 0 do
    Map.put(json, "media", %{"media_ids" => ids})
  end

  defp maybe_add_media(json, _), do: json

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
