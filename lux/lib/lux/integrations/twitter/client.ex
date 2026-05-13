defmodule Lux.Integrations.Twitter.Client do
  @moduledoc """
  Core Twitter/X API helpers.

  The module keeps credentials outside the implementation and returns request
  plans that can be executed by the caller's HTTP layer.
  """

  @api_base "https://api.twitter.com"
  @oauth_authorize_url "https://twitter.com/i/oauth2/authorize"

  @doc """
  Builds a PKCE verifier/challenge pair for OAuth 2.0 authorization code flow.
  """
  @spec pkce_pair(String.t() | nil) :: %{verifier: String.t(), challenge: String.t(), method: String.t()}
  def pkce_pair(verifier \\ nil) do
    verifier = verifier || random_verifier()

    %{
      verifier: verifier,
      challenge: code_challenge(verifier),
      method: "S256"
    }
  end

  @doc """
  Builds an OAuth 2.0 authorization URL.
  """
  @spec authorization_url(map()) :: String.t()
  def authorization_url(params) when is_map(params) do
    pkce = pkce_pair(value(params, :code_verifier))

    query =
      %{
        response_type: "code",
        client_id: value(params, :client_id),
        redirect_uri: value(params, :redirect_uri),
        scope: value(params, :scope) || "tweet.read tweet.write users.read offline.access",
        state: value(params, :state),
        code_challenge: pkce.challenge,
        code_challenge_method: pkce.method
      }
      |> drop_nil()
      |> URI.encode_query()

    @oauth_authorize_url <> "?" <> query
  end

  @doc """
  Builds token exchange or refresh request plans.
  """
  @spec token_request(atom(), map()) :: {:ok, map()} | {:error, String.t()}
  def token_request(:authorization_code, params) do
    body =
      %{
        grant_type: "authorization_code",
        code: value(params, :code),
        redirect_uri: value(params, :redirect_uri),
        client_id: value(params, :client_id),
        code_verifier: value(params, :code_verifier)
      }
      |> drop_nil()

    {:ok, request(:post, "/2/oauth2/token", body, params)}
  end

  def token_request(:refresh_token, params) do
    body =
      %{
        grant_type: "refresh_token",
        refresh_token: value(params, :refresh_token),
        client_id: value(params, :client_id)
      }
      |> drop_nil()

    {:ok, request(:post, "/2/oauth2/token", body, params)}
  end

  def token_request(flow, _params), do: {:error, "Unsupported Twitter OAuth flow: #{flow}"}

  @doc """
  Builds Twitter tweet-management request plans.
  """
  @spec tweet_request(atom(), map()) :: {:ok, map()} | {:error, String.t()}
  def tweet_request(:create, %{text: text} = params) when is_binary(text) do
    payload =
      %{text: text}
      |> put_optional(:reply, reply_payload(params))
      |> put_optional(:quote_tweet_id, value(params, :quote_tweet_id))
      |> put_optional(:media, media_payload(params))

    {:ok, request(:post, "/2/tweets", payload, params)}
  end

  def tweet_request(:delete, %{tweet_id: tweet_id} = params) do
    {:ok, request(:delete, "/2/tweets/#{tweet_id}", %{}, params)}
  end

  def tweet_request(:lookup, %{tweet_id: tweet_id} = params) do
    query =
      params
      |> take_query([:expansions, :tweet_fields, :user_fields, :media_fields])

    {:ok, request(:get, with_query("/2/tweets/#{tweet_id}", query), %{}, params)}
  end

  def tweet_request(action, _params), do: {:error, "Unsupported Twitter tweet action: #{action}"}

  @doc """
  Builds user/profile request plans.
  """
  @spec user_request(atom(), map()) :: {:ok, map()} | {:error, String.t()}
  def user_request(:me, params) do
    {:ok, request(:get, with_query("/2/users/me", take_query(params, [:user_fields])), %{}, params)}
  end

  def user_request(:lookup, %{user_id: user_id} = params) do
    {:ok, request(:get, with_query("/2/users/#{user_id}", take_query(params, [:user_fields])), %{}, params)}
  end

  def user_request(:follow, %{user_id: user_id, target_user_id: target_user_id} = params) do
    {:ok, request(:post, "/2/users/#{user_id}/following", %{target_user_id: target_user_id}, params)}
  end

  def user_request(:unfollow, %{user_id: user_id, target_user_id: target_user_id} = params) do
    {:ok, request(:delete, "/2/users/#{user_id}/following/#{target_user_id}", %{}, params)}
  end

  def user_request(action, _params), do: {:error, "Unsupported Twitter user action: #{action}"}

  @doc """
  Builds media upload request plans for the chunked v1.1 upload endpoint.
  """
  @spec media_upload_request(atom(), map()) :: {:ok, map()} | {:error, String.t()}
  def media_upload_request(:init, params) do
    payload =
      %{
        command: "INIT",
        total_bytes: value(params, :total_bytes),
        media_type: value(params, :media_type),
        media_category: value(params, :media_category)
      }
      |> drop_nil()

    {:ok, request(:post, "/1.1/media/upload.json", payload, params)}
  end

  def media_upload_request(:append, %{media_id: media_id, segment_index: segment_index, media_data: media_data} = params) do
    payload = %{
      command: "APPEND",
      media_id: media_id,
      segment_index: segment_index,
      media_data: media_data
    }

    {:ok, request(:post, "/1.1/media/upload.json", payload, params)}
  end

  def media_upload_request(:finalize, %{media_id: media_id} = params) do
    {:ok, request(:post, "/1.1/media/upload.json", %{command: "FINALIZE", media_id: media_id}, params)}
  end

  def media_upload_request(command, _params), do: {:error, "Unsupported Twitter media upload command: #{command}"}

  @doc """
  Parses Twitter rate-limit headers.
  """
  @spec rate_limit(map()) :: map()
  def rate_limit(headers) when is_map(headers) do
    %{
      limit: int_header(headers, "x-rate-limit-limit"),
      remaining: int_header(headers, "x-rate-limit-remaining"),
      reset_at: int_header(headers, "x-rate-limit-reset"),
      retry_after: int_header(headers, "retry-after"),
      limited?: int_header(headers, "x-rate-limit-remaining") == 0
    }
  end

  @doc """
  Normalizes Twitter API errors.
  """
  @spec classify_error(integer(), map() | String.t()) :: map()
  def classify_error(status, body) do
    %{
      status: status,
      type: error_type(status),
      retryable?: status in [408, 429, 500, 502, 503, 504],
      message: error_message(body)
    }
  end

  defp request(method, endpoint, payload, params) do
    %{
      method: method,
      base_url: @api_base,
      endpoint: endpoint,
      url: @api_base <> endpoint,
      headers: auth_headers(params),
      payload: payload
    }
  end

  defp auth_headers(params) do
    case value(params, :access_token) do
      nil -> []
      token -> [{"Authorization", "Bearer #{token}"}]
    end
  end

  defp reply_payload(params) do
    case value(params, :reply_to_tweet_id) do
      nil -> nil
      tweet_id -> %{in_reply_to_tweet_id: tweet_id}
    end
  end

  defp media_payload(params) do
    case value(params, :media_ids) do
      media_ids when is_list(media_ids) -> %{media_ids: media_ids}
      _other -> nil
    end
  end

  defp take_query(params, keys) do
    keys
    |> Enum.reduce(%{}, fn key, acc -> put_optional(acc, key, value(params, key)) end)
    |> Enum.map(fn {key, value} -> {Atom.to_string(key), encode_query_value(value)} end)
    |> Enum.into(%{})
  end

  defp with_query(path, query) when map_size(query) == 0, do: path
  defp with_query(path, query), do: path <> "?" <> URI.encode_query(query)

  defp encode_query_value(value) when is_list(value), do: Enum.join(value, ",")
  defp encode_query_value(value), do: value

  defp code_challenge(verifier) do
    :sha256
    |> :crypto.hash(verifier)
    |> Base.url_encode64(padding: false)
  end

  defp random_verifier do
    32
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp int_header(headers, key) do
    case Map.get(headers, key) || Map.get(headers, String.downcase(key)) do
      value when is_integer(value) -> value
      value when is_binary(value) ->
        case Integer.parse(value) do
          {parsed, _rest} -> parsed
          :error -> nil
        end

      _other ->
        nil
    end
  end

  defp error_type(status) when status in [401, 403], do: :auth
  defp error_type(404), do: :not_found
  defp error_type(429), do: :rate_limited
  defp error_type(status) when status in [500, 502, 503, 504], do: :server
  defp error_type(_status), do: :api_error

  defp error_message(%{"detail" => detail}), do: detail
  defp error_message(%{"title" => title}), do: title
  defp error_message(%{detail: detail}), do: detail
  defp error_message(%{title: title}), do: title
  defp error_message(message) when is_binary(message), do: message
  defp error_message(body), do: inspect(body)

  defp drop_nil(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.into(%{})
  end

  defp put_optional(map, _key, nil), do: map
  defp put_optional(map, key, value), do: Map.put(map, key, value)

  defp value(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
  defp value(_map, _key), do: nil
end
