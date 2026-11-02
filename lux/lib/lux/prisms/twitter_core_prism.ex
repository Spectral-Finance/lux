defmodule Lux.Prisms.TwitterCorePrism do
  @moduledoc """
  A high-level Prism enabling autonomous Lux agents to interact with Twitter (X).
  Supports posting tweets, publishing threaded stories, deleting tweets,
  fetching tweet data, looking up users, uploading media, and executing OAuth 2.0 PKCE.

  ## Examples

      iex> Lux.Prisms.TwitterCorePrism.run(%{
      ...>   action: "post_tweet",
      ...>   payload: %{text: "Autonomous AI posting on X via Lux framework!"}
      ...> })
      {:ok, %{action: "post_tweet", result: %{"id" => "12345"}}}
  """

  use Lux.Prism,
    name: "Twitter Core Prism",
    description: "Twitter API v2 operations for agents: tweet creation, deletion, lookup, threads, media upload, and OAuth 2.0 management",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: [
            "post_tweet",
            "delete_tweet",
            "get_tweet",
            "post_thread",
            "lookup_user",
            "upload_media",
            "generate_oauth_url",
            "refresh_access_token"
          ],
          description: "Twitter action to execute"
        },
        payload: %{
          type: :object,
          description: "Action-specific parameters and credentials"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        result: %{type: :object}
      },
      required: ["action", "result"]
    }

  alias Lux.Integrations.Twitter

  def handler(input, _context) do
    action = Map.get(input, :action) || Map.get(input, "action", "post_tweet")
    payload = Map.get(input, :payload) || Map.get(input, "payload", %{})

    case execute_action(action, payload) do
      {:ok, result} ->
        {:ok, %{action: action, result: result}}

      {:error, reason} ->
        {:error, "TwitterCorePrism error on action '#{action}': #{inspect(reason)}"}
    end
  end

  defp execute_action("post_tweet", payload) do
    opts = extract_client_opts(payload)
    Twitter.create_tweet(payload, opts)
  end

  defp execute_action("delete_tweet", payload) do
    tweet_id = Map.get(payload, :tweet_id, Map.get(payload, "tweet_id", ""))
    opts = extract_client_opts(payload)
    Twitter.delete_tweet(tweet_id, opts)
  end

  defp execute_action("get_tweet", payload) do
    tweet_id = Map.get(payload, :tweet_id, Map.get(payload, "tweet_id", ""))
    opts = extract_client_opts(payload)
    Twitter.get_tweet(tweet_id, opts)
  end

  defp execute_action("post_thread", payload) do
    tweets = Map.get(payload, :tweets, Map.get(payload, "tweets", []))
    opts = extract_client_opts(payload)
    Twitter.create_thread(tweets, opts)
  end

  defp execute_action("lookup_user", payload) do
    opts = extract_client_opts(payload)

    cond do
      username = Map.get(payload, :username, Map.get(payload, "username")) ->
        Twitter.get_user_by_username(username, opts)

      user_id = Map.get(payload, :user_id, Map.get(payload, "user_id")) ->
        Twitter.get_user_by_id(user_id, opts)

      true ->
        Twitter.get_me(opts)
    end
  end

  defp execute_action("upload_media", payload) do
    media_data =
      cond do
        raw = Map.get(payload, :binary_data, Map.get(payload, "binary_data")) ->
          raw

        b64 = Map.get(payload, :base64_data, Map.get(payload, "base64_data")) ->
          case Base.decode64(b64) do
            {:ok, bin} -> bin
            _ -> b64
          end

        true ->
          <<>>
      end

    media_type = Map.get(payload, :media_type, Map.get(payload, "media_type", "image/jpeg"))
    opts = extract_client_opts(payload)
    Twitter.upload_media(media_data, media_type, opts)
  end

  defp execute_action("generate_oauth_url", payload) do
    client_id = Map.get(payload, :client_id, Map.get(payload, "client_id", ""))
    redirect_uri = Map.get(payload, :redirect_uri, Map.get(payload, "redirect_uri", ""))
    challenge = Twitter.generate_pkce_challenge()
    scopes = Map.get(payload, :scopes, Map.get(payload, "scopes"))
    state = Map.get(payload, :state, Map.get(payload, "state"))

    url = Twitter.authorization_url(client_id, redirect_uri, scopes, state, challenge.code_challenge)

    {:ok,
     %{
       url: url,
       code_verifier: challenge.code_verifier,
       code_challenge: challenge.code_challenge
     }}
  end

  defp execute_action("refresh_access_token", payload) do
    client_id = Map.get(payload, :client_id, Map.get(payload, "client_id", ""))
    client_secret = Map.get(payload, :client_secret, Map.get(payload, "client_secret"))
    refresh_token = Map.get(payload, :refresh_token, Map.get(payload, "refresh_token", ""))
    opts = extract_client_opts(payload)

    Twitter.refresh_token(client_id, client_secret, refresh_token, opts)
  end

  defp execute_action(unknown, _payload) do
    {:error, "Unknown action: #{unknown}"}
  end

  defp extract_client_opts(payload) do
    opts = %{}

    opts =
      case Map.get(payload, :token, Map.get(payload, "token")) do
        nil -> opts
        token -> Map.put(opts, :token, token)
      end

    case Map.get(payload, :plug, Map.get(payload, "plug")) do
      nil -> opts
      plug -> Map.put(opts, :plug, plug)
    end
  end
end
