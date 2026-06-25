defmodule Lux.Prisms.Twitter.CreateTweet do
  @moduledoc """
  A prism for creating tweets on Twitter.

  Supports:
  - Plain text tweets
  - Tweets with media attachments (images, GIFs, videos)
  - Reply tweets
  - Thread continuation

  ## Examples

      iex> CreateTweet.handler(%{text: "Hello, world!"}, %{name: "Agent"})
      {:ok, %{id: "123456789", text: "Hello, world!", created_at: "..."}}
  """

  use Lux.Prism,
    name: "Create Tweet",
    description: "Creates a new tweet on Twitter",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{
          type: :string,
          description: "The text content of the tweet (max 280 characters)",
          minLength: 1,
          maxLength: 280
        },
        reply_to_tweet_id: %{
          type: :string,
          description: "ID of the tweet to reply to"
        },
        media_ids: %{
          type: :array,
          items: %{type: :string},
          description: "List of media IDs to attach (from media upload)"
        },
        poll: %{
          type: :object,
          description: "Poll to attach to the tweet",
          properties: %{
            options: %{
              type: :array,
              items: %{type: :string},
              description: "Poll options (2-4 options)"
            },
            duration_minutes: %{
              type: :integer,
              description: "Duration in minutes (10, 30, 60, 120, 240, 480, 1440)"
            }
          }
        },
        excludes: %{
          type: :object,
          description: "Types of tweets to exclude from replies",
          properties: %{
            retweets: %{type: :boolean},
            replies: %{type: :boolean}
          }
        }
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string, description: "The ID of the created tweet"},
        text: %{type: :string, description: "The text of the created tweet"},
        created_at: %{type: :string, description: "ISO 8601 timestamp"},
        author_id: %{type: :string, description: "ID of the author"}
      },
      required: ["id", "text"]
    }

  alias Lux.Integrations.Twitter.Client
  require Logger

  @doc """
  Handles creating a tweet.

  Returns {:ok, %{id, text, created_at, author_id}} on success.
  Returns {:error, reason} on failure.
  """
  def handler(params, agent) do
    with {:ok, text} <- validate_param(params, :text),
         {:ok, _} <- validate_tweet_length(text),
         {:ok, reply_to} <- validate_optional_string(params, :reply_to_tweet_id),
         {:ok, media_ids} <- validate_optional_array(params, :media_ids),
         {:ok, poll} <- validate_optional_map(params, :poll),
         {:ok, excludes} <- validate_optional_map(params, :excludes) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} creating tweet: #{String.slice(text, 0, 50)}...")

      body = build_tweet_body(text, reply_to, media_ids, poll, excludes)

      case Client.request(:post, "/tweets", %{json: body}) do
        {:ok, %{"data" => tweet_data}} ->
          Logger.info("Successfully created tweet #{tweet_data["id"]}")
          {:ok, Map.take(tweet_data, ["id", "text", "created_at", "author_id"])}

        {:error, {status, %{"errors" => errors}}} when is_list(errors) ->
          error_msg = List.first(errors) |> Map.get("message", "Unknown error")
          Logger.error("Failed to create tweet: #{error_msg}")
          {:error, {status, error_msg}}

        {:error, {status, %{"title" => title, "detail" => detail}}} ->
          Logger.error("Failed to create tweet: #{title} - #{detail}")
          {:error, {status, detail}}

        {:error, error} ->
          Logger.error("Failed to create tweet: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  # Build the tweet request body
  defp build_tweet_body(text, nil, nil, nil, nil),
    do: %{text: text}

  defp build_tweet_body(text, reply_to, nil, nil, nil),
    do: %{text: text, reply: %{in_reply_to_tweet_id: reply_to}}

  defp build_tweet_body(text, nil, media_ids, nil, nil),
    do: %{text: text, media: %{media_ids: media_ids}}

  defp build_tweet_body(text, nil, nil, poll, nil),
    do: %{text: text, poll: build_poll(poll)}

  defp build_tweet_body(text, nil, nil, nil, excludes),
    do: %{text: text, excludes: excludes}

  defp build_tweet_body(text, reply_to, media_ids, poll, excludes) do
    body = %{text: text}

    body =
      if reply_to do
        Map.put(body, :reply, %{in_reply_to_tweet_id: reply_to})
      else
        body
      end

    body =
      if media_ids do
        Map.put(body, :media, %{media_ids: media_ids})
      else
        body
      end

    body =
      if poll do
        Map.put(body, :poll, build_poll(poll))
      else
        body
      end

    body =
      if excludes do
        Map.put(body, :excludes, excludes)
      else
        body
      end

    body
  end

  defp build_poll(poll) do
    %{
      options: poll[:options] || poll["options"],
      duration_minutes: poll[:duration_minutes] || poll["duration_minutes"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp validate_tweet_length(text) when byte_size(text) <= 280, do: {:ok, text}
  defp validate_tweet_length(text), do: {:error, "Tweet text exceeds 280 character limit (got #{byte_size(text)})"}

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_optional_string(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) -> {:ok, value}
      :error -> {:ok, nil}
      _ -> {:error, "Invalid #{key}"}
    end
  end

  defp validate_optional_array(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_list(value) -> {:ok, value}
      :error -> {:ok, nil}
      _ -> {:error, "Invalid #{key}"}
    end
  end

  defp validate_optional_map(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_map(value) -> {:ok, value}
      :error -> {:ok, nil}
      _ -> {:error, "Invalid #{key}"}
    end
  end
end
