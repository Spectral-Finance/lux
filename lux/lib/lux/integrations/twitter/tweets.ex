defmodule Lux.Integrations.Twitter.Tweets do
  @moduledoc """
  Core operations for managing tweets via Twitter API v2 (`/2/tweets`).
  Supports tweet creation, deletion, lookup, quote tweets, replies, polls,
  and automated thread creation.
  """

  alias Lux.Integrations.Twitter.Client

  @default_tweet_fields [
    "id",
    "text",
    "created_at",
    "author_id",
    "conversation_id",
    "public_metrics",
    "entities",
    "attachments"
  ]

  @default_expansions [
    "author_id",
    "attachments.media_keys",
    "referenced_tweets.id"
  ]

  @doc """
  Creates a new tweet.

  ## Parameters
    * `params` - Map of tweet options:
      * `:text` (required if media not present) - Tweet body string
      * `:media_ids` - List of Twitter media ID strings
      * `:reply_to_tweet_id` - Tweet ID to reply to
      * `:quote_tweet_id` - Tweet ID to quote
      * `:poll` - Map with `:options` (list of strings) and `:duration_minutes` (integer)
      * `:reply_settings` - `"mentionedUsers"`, `"following"`, etc.
    * `opts` - Client request options (e.g. `:token`, `:plug`)
  """
  @spec create_tweet(map(), map()) :: {:ok, map()} | {:error, term()}
  def create_tweet(params, opts \\ %{}) do
    json_payload = build_create_payload(params)

    req_opts =
      opts
      |> Map.put(:json, json_payload)

    Client.request(:post, "/tweets", req_opts)
  end

  @doc """
  Deletes an existing tweet by ID.
  """
  @spec delete_tweet(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def delete_tweet(tweet_id, opts \\ %{}) do
    Client.request(:delete, "/tweets/#{tweet_id}", opts)
  end

  @doc """
  Retrieves a tweet by ID with detailed expansions and metrics.
  """
  @spec get_tweet(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def get_tweet(tweet_id, opts \\ %{}) do
    fields = Map.get(opts, :fields, @default_tweet_fields)
    expansions = Map.get(opts, :expansions, @default_expansions)

    query_params = %{
      "tweet.fields" => Enum.join(fields, ","),
      "expansions" => Enum.join(expansions, ",")
    }

    req_opts =
      opts
      |> Map.put(:params, query_params)

    Client.request(:get, "/tweets/#{tweet_id}", req_opts)
  end

  @doc """
  Publishes a sequential thread of tweets, automatically chaining each tweet's
  `in_reply_to_tweet_id` to the predecessor.
  """
  @spec create_thread(list(String.t() | map()), map()) :: {:ok, list(map())} | {:error, term()}
  def create_thread(tweets, opts \\ %{}) when is_list(tweets) do
    Enum.reduce_while(tweets, {:ok, []}, fn tweet_item, {:ok, acc} ->
      base_params =
        case tweet_item do
          text when is_binary(text) -> %{text: text}
          %{} = map -> map
        end

      params =
        case acc do
          [] ->
            base_params

          [%{"data" => %{"id" => prev_id}} | _] ->
            Map.put(base_params, :reply_to_tweet_id, prev_id)

          [%{id: prev_id} | _] ->
            Map.put(base_params, :reply_to_tweet_id, prev_id)
        end

      case create_tweet(params, opts) do
        {:ok, created} ->
          {:cont, {:ok, [created | acc]}}

        {:error, reason} ->
          {:halt, {:error, {reason, Enum.reverse(acc)}}}
      end
    end)
    |> case do
      {:ok, published_reversed} -> {:ok, Enum.reverse(published_reversed)}
      error -> error
    end
  end

  defp build_create_payload(params) do
    payload = %{}

    payload =
      case Map.get(params, :text, Map.get(params, "text")) do
        nil -> payload
        text -> Map.put(payload, "text", text)
      end

    payload =
      case Map.get(params, :media_ids, Map.get(params, "media_ids")) do
        nil -> payload
        [] -> payload
        ids when is_list(ids) -> Map.put(payload, "media", %{"media_ids" => ids})
      end

    payload =
      case Map.get(params, :reply_to_tweet_id, Map.get(params, "reply_to_tweet_id")) do
        nil ->
          payload

        reply_id ->
          Map.put(payload, "reply", %{"in_reply_to_tweet_id" => to_string(reply_id)})
      end

    payload =
      case Map.get(params, :quote_tweet_id, Map.get(params, "quote_tweet_id")) do
        nil -> payload
        quote_id -> Map.put(payload, "quote_tweet_id", to_string(quote_id))
      end

    payload =
      case Map.get(params, :poll, Map.get(params, "poll")) do
        %{options: options, duration_minutes: mins} ->
          Map.put(payload, "poll", %{"options" => options, "duration_minutes" => mins})

        %{"options" => options, "duration_minutes" => mins} ->
          Map.put(payload, "poll", %{"options" => options, "duration_minutes" => mins})

        _ ->
          payload
      end

    payload
  end
end
