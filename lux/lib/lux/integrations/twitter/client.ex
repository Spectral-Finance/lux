defmodule Lux.Integrations.Twitter.Client do
  @moduledoc """
  Client for interacting with the Twitter API v2.
  Handles HTTP requests, OAuth 2.0 authentication, rate limiting, and error parsing.
  """

  require Logger
  alias Lux.Integrations.Twitter

  @base_url "https://api.twitter.com/2"
  @media_url "https://upload.twitter.com/1.1"

  @type request_opts :: %{
    optional(:token) => String.t(),
    optional(:json) => map(),
    optional(:query) => Keyword.t() | map(),
    optional(:headers) => [{String.t(), String.t()}],
    optional(:multipart) => list(),
    optional(:plug) => {module(), term()}
  }

  @doc """
  Posts a tweet.
  """
  def create_tweet(text, opts \\ %{}) do
    payload = Map.merge(%{text: text}, Map.take(opts, [:media, :reply, :quote_tweet_id]))
    request(:post, "/tweets", Map.put(opts, :json, payload))
  end

  @doc """
  Deletes a tweet.
  """
  def delete_tweet(tweet_id, opts \\ %{}) do
    request(:delete, "/tweets/#{tweet_id}", opts)
  end

  @doc """
  Edits a tweet. (Note: Only available to some verified accounts)
  """
  def edit_tweet(tweet_id, text, opts \\ %{}) do
    payload = %{text: text}
    request(:put, "/tweets/#{tweet_id}", Map.put(opts, :json, payload))
  end

  @doc """
  Replies to a tweet.
  """
  def reply_to_tweet(tweet_id, text, opts \\ %{}) do
    payload = %{text: text, reply: %{in_reply_to_tweet_id: tweet_id}}
    request(:post, "/tweets", Map.put(opts, :json, payload))
  end

  @doc """
  Quotes a tweet.
  """
  def quote_tweet(tweet_id, text, opts \\ %{}) do
    payload = %{text: text, quote_tweet_id: tweet_id}
    request(:post, "/tweets", Map.put(opts, :json, payload))
  end

  @doc """
  Creates a thread of tweets.
  """
  def create_thread(tweets, opts \\ %{}) when is_list(tweets) do
    # Twitter v2 doesn't have a batch create thread endpoint.
    # We must post them sequentially, replying to the previous one.
    Enum.reduce_while(tweets, {:ok, []}, fn text, {:ok, acc} ->
      payload = if acc == [] do
        %{text: text}
      else
        last_id = List.last(acc)["data"]["id"]
        %{text: text, reply: %{in_reply_to_tweet_id: last_id}}
      end

      case request(:post, "/tweets", Map.put(opts, :json, payload)) do
        {:ok, response} -> {:cont, {:ok, acc ++ [response]}}
        {:error, err} -> {:halt, {:error, {err, acc}}}
      end
    end)
  end

  @doc """
  Fetches user profile.
  """
  def get_user_profile(username, opts \\ %{}) do
    query = %{"user.fields" => "description,public_metrics,profile_image_url"}
    opts = Map.put(opts, :query, query)
    request(:get, "/users/by/username/#{username}", opts)
  end

  @doc """
  Sends a direct message.
  """
  def send_dm(participant_id, text, opts \\ %{}) do
    payload = %{
      event: %{
        type: "message_create",
        message_create: %{
          target: %{participant_id: participant_id},
          message_data: %{text: text}
        }
      }
    }
    request(:post, "/dm_events", Map.put(opts, :json, payload))
  end

  @doc """
  Follows a user.
  """
  def follow_user(source_user_id, target_user_id, opts \\ %{}) do
    payload = %{target_user_id: target_user_id}
    request(:post, "/users/#{source_user_id}/following", Map.put(opts, :json, payload))
  end

  @doc """
  Unfollows a user.
  """
  def unfollow_user(source_user_id, target_user_id, opts \\ %{}) do
    request(:delete, "/users/#{source_user_id}/following/#{target_user_id}", opts)
  end

  @doc """
  Makes a request to the Twitter API v2.
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    token = opts[:token] || bearer_token()
    url = @base_url <> path

    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ] ++ Map.get(opts, :headers, [])

    [
      method: method,
      url: url,
      headers: headers,
      json: opts[:json],
      params: opts[:query],
      multipart: opts[:multipart]
    ]
    |> Keyword.reject(fn {_, v} -> is_nil(v) end)
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(opts[:plug])
    |> Req.new()
    |> Req.request()
    |> handle_response()
  end

  defp bearer_token do
    Lux.Config.twitter_bearer_token()
  end

  defp handle_response({:ok, %{status: status} = response}) when status in 200..299 do
    case response.body do
      %{"errors" => errors} = body ->
        if Map.has_key?(body, "data") do
          {:ok, body}
        else
          {:error, errors}
        end
      body ->
        {:ok, body}
    end
  end

  defp handle_response({:ok, %{status: 429} = response}) do
    reset_time = Req.Response.get_header(response, "x-rate-limit-reset") |> List.first()
    limit = Req.Response.get_header(response, "x-rate-limit-limit") |> List.first()
    remaining = Req.Response.get_header(response, "x-rate-limit-remaining") |> List.first()

    Logger.warning("Twitter API rate limit exceeded. Reset at: #{reset_time}")

    {:error, :rate_limit_exceeded, %{reset_time: reset_time, limit: limit, remaining: remaining}}
  end

  defp handle_response({:ok, %{status: 401}}) do
    {:error, :unauthorized}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    {:error, {status, body}}
  end

  defp handle_response({:error, error}) do
    {:error, error}
  end

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)
end
