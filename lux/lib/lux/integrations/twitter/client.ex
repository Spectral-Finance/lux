defmodule Lux.Integrations.Twitter.Client do
  @moduledoc """
  Twitter/X API v2 client.

  The module provides OAuth 2.0 PKCE helpers, token request helpers, and typed
  convenience functions for posts, users, follows, and chunked media upload.
  """

  alias Lux.Integrations.Twitter

  @token_path "/2/oauth2/token"
  @media_upload_path "/2/media/upload"

  @type opts :: keyword() | map()
  @type request_result :: {:ok, term()} | {:error, term()}

  @doc """
  Makes a raw X API request.

  Options:

    * `:access_token` or `:bearer_token` - bearer token for authenticated endpoints
    * `:json` - JSON request body
    * `:form` - URL-encoded form body
    * `:form_multipart` - multipart form body
    * `:headers` - additional headers
    * `:auth` - set to `false` for public/token endpoints
    * `:plug` - Req.Test plug for unit tests
    * `:with_rate_limit` - return `%{body: body, rate_limit: limit}` on success
  """
  @spec request(atom(), String.t(), opts()) :: request_result()
  def request(method, path, opts \\ %{}) do
    opts = normalize_opts(opts)

    [
      method: method,
      url: url(path, opts),
      headers: request_headers(opts),
      retry: opt(opts, :retry, false)
    ]
    |> maybe_put(:json, opt(opts, :json))
    |> maybe_put(:form, opt(opts, :form))
    |> maybe_put(:form_multipart, opt(opts, :form_multipart))
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(opt(opts, :plug))
    |> Req.new()
    |> Req.request()
    |> handle_response(opts)
  end

  @doc """
  Builds a PKCE verifier/challenge pair.
  """
  @spec pkce_pair(String.t() | nil) :: %{
          verifier: String.t(),
          challenge: String.t(),
          method: String.t()
        }
  def pkce_pair(verifier \\ nil) do
    verifier = verifier || random_verifier()

    %{
      verifier: verifier,
      challenge: code_challenge(verifier),
      method: "S256"
    }
  end

  @doc """
  Builds the OAuth 2.0 authorization URL for Authorization Code with PKCE.
  """
  @spec authorization_url(opts()) :: String.t()
  def authorization_url(opts) do
    opts = normalize_opts(opts)
    pkce = pkce_pair(opt(opts, :code_verifier))
    scopes = opt(opts, :scopes, opt(opts, :scope, Twitter.default_scopes()))

    query =
      %{
        response_type: "code",
        client_id: opt(opts, :client_id),
        redirect_uri: opt(opts, :redirect_uri),
        state: opt(opts, :state),
        scope: encode_scope(scopes),
        code_challenge: pkce.challenge,
        code_challenge_method: pkce.method
      }
      |> drop_nil()
      |> URI.encode_query()

    Twitter.authorize_url() <> "?" <> query
  end

  @doc """
  Exchanges an authorization code or refresh token for OAuth tokens.
  """
  @spec token_request(:authorization_code | :refresh_token, opts()) :: request_result()
  def token_request(:authorization_code, opts) do
    opts = normalize_opts(opts)

    form =
      %{
        grant_type: "authorization_code",
        code: opt(opts, :code),
        redirect_uri: opt(opts, :redirect_uri),
        client_id: opt(opts, :client_id),
        code_verifier: opt(opts, :code_verifier)
      }
      |> drop_nil()
      |> Map.to_list()

    request(:post, @token_path, token_opts(opts, form))
  end

  def token_request(:refresh_token, opts) do
    opts = normalize_opts(opts)

    form =
      %{
        grant_type: "refresh_token",
        refresh_token: opt(opts, :refresh_token),
        client_id: opt(opts, :client_id)
      }
      |> drop_nil()
      |> Map.to_list()

    request(:post, @token_path, token_opts(opts, form))
  end

  @doc """
  Creates a post, reply, quote post, or edit.
  """
  @spec create_tweet(opts(), opts()) :: request_result()
  def create_tweet(params, opts \\ %{}) do
    request(:post, "/2/tweets", put_request_body(opts, tweet_payload(params)))
  end

  @doc """
  Edits a post by creating a replacement post with `edit_options.previous_post_id`.
  """
  @spec edit_tweet(String.t(), opts(), opts()) :: request_result()
  def edit_tweet(previous_tweet_id, params, opts \\ %{}) do
    params
    |> normalize_opts()
    |> Map.put(:edit_options, %{previous_post_id: previous_tweet_id})
    |> create_tweet(opts)
  end

  @doc """
  Deletes a post.
  """
  @spec delete_tweet(String.t(), opts()) :: request_result()
  def delete_tweet(tweet_id, opts \\ %{}) do
    request(:delete, "/2/tweets/#{tweet_id}", opts)
  end

  @doc """
  Looks up a post by ID.
  """
  @spec get_tweet(String.t(), opts(), opts()) :: request_result()
  def get_tweet(tweet_id, params \\ %{}, opts \\ %{}) do
    request(:get, query_path("/2/tweets/#{tweet_id}", params), opts)
  end

  @doc """
  Creates a quote post.
  """
  @spec quote_tweet(String.t(), String.t(), opts()) :: request_result()
  def quote_tweet(text, quoted_tweet_id, opts \\ %{}) do
    create_tweet(%{text: text, quote_tweet_id: quoted_tweet_id}, opts)
  end

  @doc """
  Creates a thread by replying each post to the previous post.
  """
  @spec create_thread([String.t()], opts()) :: request_result()
  def create_thread(texts, opts \\ %{}) when is_list(texts) do
    texts
    |> Enum.reduce_while({:ok, nil, []}, fn text, {:ok, previous_id, responses} ->
      params =
        if previous_id, do: %{text: text, reply_to_tweet_id: previous_id}, else: %{text: text}

      case create_tweet(params, opts) do
        {:ok, %{"data" => %{"id" => tweet_id}} = response} ->
          {:cont, {:ok, tweet_id, [response | responses]}}

        {:ok, response} ->
          {:halt, {:error, {:missing_tweet_id, response}}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, _last_id, responses} -> {:ok, Enum.reverse(responses)}
      error -> error
    end
  end

  @doc """
  Gets the authenticated user.
  """
  @spec get_me(opts(), opts()) :: request_result()
  def get_me(params \\ %{}, opts \\ %{}) do
    request(:get, query_path("/2/users/me", params), opts)
  end

  @doc """
  Looks up a user by ID.
  """
  @spec get_user(String.t(), opts(), opts()) :: request_result()
  def get_user(user_id, params \\ %{}, opts \\ %{}) do
    request(:get, query_path("/2/users/#{user_id}", params), opts)
  end

  @doc """
  Looks up a user by username.
  """
  @spec get_user_by_username(String.t(), opts(), opts()) :: request_result()
  def get_user_by_username(username, params \\ %{}, opts \\ %{}) do
    request(:get, query_path("/2/users/by/username/#{username}", params), opts)
  end

  @doc """
  Follows a user.
  """
  @spec follow_user(String.t(), String.t(), opts()) :: request_result()
  def follow_user(source_user_id, target_user_id, opts \\ %{}) do
    request(
      :post,
      "/2/users/#{source_user_id}/following",
      put_request_body(opts, %{target_user_id: target_user_id})
    )
  end

  @doc """
  Unfollows a user.
  """
  @spec unfollow_user(String.t(), String.t(), opts()) :: request_result()
  def unfollow_user(source_user_id, target_user_id, opts \\ %{}) do
    request(:delete, "/2/users/#{source_user_id}/following/#{target_user_id}", opts)
  end

  @doc """
  Runs one step of the chunked media upload workflow.
  """
  @spec media_upload(:init | :append | :finalize | :status, opts(), opts()) :: request_result()
  def media_upload(action, params, opts \\ %{})

  def media_upload(:init, params, opts) do
    fields =
      multipart_fields(%{
        command: "INIT",
        total_bytes: value(params, :total_bytes),
        media_type: value(params, :media_type),
        media_category: value(params, :media_category)
      })

    request(:post, @media_upload_path, put_multipart_body(opts, fields))
  end

  def media_upload(:append, params, opts) do
    fields =
      multipart_fields(%{
        command: "APPEND",
        media_id: value(params, :media_id),
        segment_index: value(params, :segment_index),
        media: value(params, :media)
      })

    request(:post, @media_upload_path, put_multipart_body(opts, fields))
  end

  def media_upload(:finalize, params, opts) do
    fields =
      multipart_fields(%{
        command: "FINALIZE",
        media_id: value(params, :media_id)
      })

    request(:post, @media_upload_path, put_multipart_body(opts, fields))
  end

  def media_upload(:status, params, opts) do
    request(
      :get,
      query_path(@media_upload_path, %{command: "STATUS", media_id: value(params, :media_id)}),
      opts
    )
  end

  @doc """
  Measures a local function and returns elapsed microseconds.
  """
  @spec benchmark((-> term()), pos_integer()) :: %{
          iterations: pos_integer(),
          total_us: non_neg_integer(),
          average_us: float()
        }
  def benchmark(fun, iterations \\ 1_000) when is_function(fun, 0) and iterations > 0 do
    {total_us, _} =
      :timer.tc(fn ->
        for _ <- 1..iterations, do: fun.()
      end)

    %{
      iterations: iterations,
      total_us: total_us,
      average_us: total_us / iterations
    }
  end

  defp handle_response({:ok, %{status: status} = response}, opts) when status in 200..299 do
    body = response.body

    if opt(opts, :with_rate_limit, false) do
      {:ok, %{body: body, rate_limit: Twitter.rate_limit(response.headers)}}
    else
      {:ok, body}
    end
  end

  defp handle_response({:ok, %{status: status, body: body, headers: headers}}, _opts) do
    {:error, Twitter.classify_error(status, body, headers)}
  end

  defp handle_response({:error, error}, _opts), do: {:error, error}

  defp url(path, opts) do
    if String.starts_with?(path, "http") do
      path
    else
      opt(opts, :api_base_url, Twitter.api_base_url()) <> path
    end
  end

  defp request_headers(opts) do
    opts
    |> opt(:headers, [])
    |> normalize_headers()
    |> maybe_put_accept()
    |> maybe_put_content_type(opts)
    |> maybe_put_authorization(opts)
  end

  defp maybe_put_accept(headers), do: put_header(headers, "Accept", "application/json")

  defp maybe_put_content_type(headers, opts) do
    cond do
      opt(opts, :form_multipart) -> headers
      opt(opts, :form) -> put_header(headers, "Content-Type", "application/x-www-form-urlencoded")
      opt(opts, :json) -> put_header(headers, "Content-Type", "application/json")
      true -> headers
    end
  end

  defp maybe_put_authorization(headers, opts) do
    cond do
      opt(opts, :auth, true) == false ->
        headers

      has_header?(headers, "authorization") ->
        headers

      true ->
        token = opt(opts, :access_token, opt(opts, :bearer_token, Twitter.bearer_token()))
        [{"Authorization", "Bearer #{token}"} | headers]
    end
  end

  defp token_opts(opts, form) do
    opts
    |> Map.merge(%{
      auth: false,
      form: form,
      headers: token_headers(opts)
    })
  end

  defp token_headers(opts) do
    client_id = opt(opts, :client_id)
    client_secret = opt(opts, :client_secret)

    if client_id && client_secret do
      [{"Authorization", "Basic " <> Base.encode64("#{client_id}:#{client_secret}")}]
    else
      []
    end
  end

  defp tweet_payload(params) do
    params = normalize_opts(params)

    %{
      text: opt(params, :text),
      card_uri: opt(params, :card_uri),
      community_id: opt(params, :community_id),
      direct_message_deep_link: opt(params, :direct_message_deep_link),
      for_super_followers_only: opt(params, :for_super_followers_only),
      geo: opt(params, :geo),
      nullcast: opt(params, :nullcast),
      poll: opt(params, :poll),
      quote_tweet_id: opt(params, :quote_tweet_id),
      reply: reply_payload(params),
      reply_settings: opt(params, :reply_settings),
      media: media_payload(params),
      edit_options: opt(params, :edit_options)
    }
    |> drop_nil()
  end

  defp reply_payload(params) do
    %{
      in_reply_to_tweet_id: opt(params, :reply_to_tweet_id),
      exclude_reply_user_ids: opt(params, :exclude_reply_user_ids)
    }
    |> drop_nil()
    |> empty_to_nil()
  end

  defp media_payload(params) do
    %{
      media_ids: opt(params, :media_ids),
      tagged_user_ids: opt(params, :tagged_user_ids)
    }
    |> drop_nil()
    |> empty_to_nil()
  end

  defp query_path(path, params) do
    params =
      params
      |> normalize_opts()
      |> Enum.reduce(%{}, fn {key, value}, acc ->
        if is_nil(value) do
          acc
        else
          Map.put(acc, query_key(key), query_value(value))
        end
      end)

    if map_size(params) == 0 do
      path
    else
      path <> "?" <> URI.encode_query(params)
    end
  end

  defp query_key(:tweet_fields), do: "tweet.fields"
  defp query_key(:user_fields), do: "user.fields"
  defp query_key(:media_fields), do: "media.fields"
  defp query_key(:place_fields), do: "place.fields"
  defp query_key(:poll_fields), do: "poll.fields"
  defp query_key(key), do: to_string(key)

  defp query_value(values) when is_list(values), do: Enum.join(values, ",")
  defp query_value(value), do: to_string(value)

  defp put_request_body(opts, body) do
    opts
    |> normalize_opts()
    |> Map.put(:json, body)
  end

  defp put_multipart_body(opts, fields) do
    opts
    |> normalize_opts()
    |> Map.put(:form_multipart, fields)
  end

  defp multipart_fields(params) do
    params
    |> drop_nil()
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
  end

  defp code_challenge(verifier) do
    verifier
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.url_encode64(padding: false)
  end

  defp random_verifier do
    64
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp encode_scope(scopes) when is_list(scopes), do: Enum.join(scopes, " ")
  defp encode_scope(scope), do: scope

  defp maybe_put(options, _key, nil), do: options
  defp maybe_put(options, key, value), do: Keyword.put(options, key, value)

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)

  defp normalize_opts(opts) when is_map(opts), do: opts
  defp normalize_opts(opts) when is_list(opts), do: Map.new(opts)

  defp opt(opts, key, default \\ nil) do
    cond do
      Map.has_key?(opts, key) -> Map.fetch!(opts, key)
      Map.has_key?(opts, to_string(key)) -> Map.fetch!(opts, to_string(key))
      true -> default
    end
  end

  defp value(params, key), do: params |> normalize_opts() |> opt(key)

  defp normalize_headers(headers) when is_map(headers), do: Map.to_list(headers)
  defp normalize_headers(headers) when is_list(headers), do: headers

  defp put_header(headers, key, value) do
    if has_header?(headers, key) do
      headers
    else
      [{key, value} | headers]
    end
  end

  defp has_header?(headers, key) do
    key = String.downcase(key)
    Enum.any?(headers, fn {header_key, _} -> String.downcase(to_string(header_key)) == key end)
  end

  defp drop_nil(map), do: Map.reject(map, fn {_key, value} -> is_nil(value) end)

  defp empty_to_nil(map) when map_size(map) == 0, do: nil
  defp empty_to_nil(map), do: map
end
