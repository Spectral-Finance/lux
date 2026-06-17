defmodule Lux.Prisms.Twitter.Tweets.CreateTweet do
  @moduledoc """
  A prism for creating tweets via Twitter API v2.

  Supports:
  - Simple text tweets
  - Tweets with media attachments
  - Reply tweets
  - Quote tweets
  - Poll tweets

  ## Examples

      iex> CreateTweet.handler(%{text: "Hello from Lux!"}, %{name: "Agent"})
      {:ok, %{
        created: true,
        tweet_id: "1234567890",
        text: "Hello from Lux!"
      }}

      iex> CreateTweet.handler(%{
      ...>   text: "Check this out!",
      ...>   quote_tweet_id: "9876543210"
      ...> }, %{name: "Agent"})
      {:ok, %{created: true, tweet_id: "...", text: "Check this out!"}}
  """

  use Lux.Prism,
    name: "Create Tweet",
    description: "Creates a new tweet on Twitter",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{
          type: :string,
          description: "The text content of the tweet",
          minLength: 1,
          maxLength: 280
        },
        reply_to_tweet_id: %{
          type: :string,
          description: "Tweet ID to reply to"
        },
        quote_tweet_id: %{
          type: :string,
          description: "Tweet ID to quote"
        },
        media_ids: %{
          type: :array,
          description: "List of media IDs to attach",
          items: %{type: :string}
        },
        poll_options: %{
          type: :array,
          description: "Poll options (2-4 choices)",
          items: %{type: :string}
        },
        poll_duration_minutes: %{
          type: :integer,
          description: "Poll duration in minutes (5-10080)",
          minimum: 5,
          maximum: 10080
        }
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        created: %{
          type: :boolean,
          description: "Whether the tweet was successfully created"
        },
        tweet_id: %{
          type: :string,
          description: "The ID of the created tweet"
        },
        text: %{
          type: :string,
          description: "The text of the created tweet"
        }
      },
      required: ["created"]
    }

  alias Lux.Integrations.Twitter.Client
  require Logger

  @doc """
  Handles the request to create a tweet.
  """
  def handler(params, agent) do
    with {:ok, text} <- validate_param(params, :text) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} creating tweet: #{String.slice(text, 0, 50)}...")

      json = build_tweet_body(params)

      case Client.request(:post, "/tweets", %{json: json}) do
        {:ok, %{"data" => %{"id" => tweet_id, "text" => tweet_text}}} ->
          Logger.info("Successfully created tweet #{tweet_id}")
          {:ok, %{created: true, tweet_id: tweet_id, text: tweet_text}}

        {:ok, %{"data" => data}} ->
          tweet_id = data["id"]
          tweet_text = data["text"]
          Logger.info("Successfully created tweet #{tweet_id}")
          {:ok, %{created: true, tweet_id: tweet_id, text: tweet_text}}

        {:error, {status, message}} ->
          Logger.error("Failed to create tweet: #{status} - #{inspect(message)}")
          {:error, {status, message}}

        {:error, error} ->
          Logger.error("Failed to create tweet: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp build_tweet_body(params) do
    %{"text" => params[:text] || params["text"]}
    |> maybe_add_reply(params)
    |> maybe_add_quote(params)
    |> maybe_add_media(params)
    |> maybe_add_poll(params)
  end

  defp maybe_add_reply(json, %{reply_to_tweet_id: reply_id}) when is_binary(reply_id) and reply_id != "" do
    Map.put(json, "reply", %{"in_reply_to_tweet_id" => reply_id})
  end

  defp maybe_add_reply(json, %{"reply_to_tweet_id" => reply_id}) when is_binary(reply_id) and reply_id != "" do
    Map.put(json, "reply", %{"in_reply_to_tweet_id" => reply_id})
  end

  defp maybe_add_reply(json, _), do: json

  defp maybe_add_quote(json, %{quote_tweet_id: quote_id}) when is_binary(quote_id) and quote_id != "" do
    Map.put(json, "quote_tweet_id", quote_id)
  end

  defp maybe_add_quote(json, %{"quote_tweet_id" => quote_id}) when is_binary(quote_id) and quote_id != "" do
    Map.put(json, "quote_tweet_id", quote_id)
  end

  defp maybe_add_quote(json, _), do: json

  defp maybe_add_media(json, %{media_ids: ids}) when is_list(ids) and length(ids) > 0 do
    Map.put(json, "media", %{"media_ids" => ids})
  end

  defp maybe_add_media(json, %{"media_ids" => ids}) when is_list(ids) and length(ids) > 0 do
    Map.put(json, "media", %{"media_ids" => ids})
  end

  defp maybe_add_media(json, _), do: json

  defp maybe_add_poll(json, %{poll_options: options}) when is_list(options) and length(options) >= 2 do
    duration = json[:poll_duration_minutes] || json["poll_duration_minutes"] || 1440
    Map.put(json, "poll", %{"options" => options, "duration_minutes" => duration})
  end

  defp maybe_add_poll(json, _), do: json

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
