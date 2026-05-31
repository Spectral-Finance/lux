defmodule Lux.Integrations.Twitter.Client do
  @moduledoc """
  HTTP client and OAuth helpers for X/Twitter API v2.

  The client covers the core issue surface: OAuth 2.0 PKCE, token refresh,
  tweet create/read/delete/edit/quote/thread operations, chunked media upload,
  user lookup/social-graph/follow management, structured rate-limit handling,
  and testable request injection through `Req.Test`.
  """

  alias Lux.Integrations.Twitter

  @type opts :: map() | keyword()
  @type result :: {:ok, term()} | {:error, term()}

  @token_path "/2/oauth2/token"
  @media_path "/2/media/upload"
  @media_initialize_path "/2/media/upload/initialize"

  @spec request(atom(), String.t(), opts()) :: result()
  def request(method, path, opts \\ %{}) do
    opts = normalize(opts)

    [
      method: method,
      url: url(path, opts),
      headers: headers(opts),
      retry: opts[:retry] || false
    ]
    |> maybe_put(:json, opts[:json])
    |> maybe_put(:form, opts[:form])
    |> maybe_put(:form_multipart, opts[:form_multipart])
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_put(:plug, opts[:plug])
    |> Req.new()
    |> Req.request()
    |> handle_response(opts)
  end

  @spec pkce_pair(String.t() | nil) :: map()
  def pkce_pair(verifier \\ nil) do
    verifier = verifier || random_verifier()

    %{
      verifier: verifier,
      challenge:
        :crypto.hash(:sha256, verifier)
        |> Base.url_encode64(padding: false),
      method: "S256"
    }
  end

  @spec authorization_url(opts()) :: String.t()
  def authorization_url(opts) do
    opts = normalize(opts)
    pkce = pkce_pair(opts[:code_verifier])
    scopes = opts[:scopes] || opts[:scope] || Twitter.default_scopes()

    query =
      %{
        response_type: "code",
        client_id: opts[:client_id],
        redirect_uri: opts[:redirect_uri],
        state: opts[:state],
        scope: encode_scope(scopes),
        code_challenge: pkce.challenge,
        code_challenge_method: pkce.method
      }
      |> drop_nil()
      |> URI.encode_query()

    "#{Twitter.authorize_url()}?#{query}"
  end

  @spec token_request(:authorization_code | :refresh_token, opts()) :: result()
  def token_request(:authorization_code, opts) do
    opts = normalize(opts)

    with :ok <- require_fields(opts, [:client_id, :code, :redirect_uri, :code_verifier]) do
      form =
        %{
          grant_type: "authorization_code",
          code: opts[:code],
          redirect_uri: opts[:redirect_uri],
          client_id: opts[:client_id],
          code_verifier: opts[:code_verifier]
        }
        |> Map.to_list()

      request(:post, @token_path, token_opts(opts, form))
    end
  end

  def token_request(:refresh_token, opts) do
    opts = normalize(opts)

    with :ok <- require_fields(opts, [:client_id, :refresh_token]) do
      form =
        %{
          grant_type: "refresh_token",
          refresh_token: opts[:refresh_token],
          client_id: opts[:client_id]
        }
        |> Map.to_list()

      request(:post, @token_path, token_opts(opts, form))
    end
  end

  @spec create_tweet(opts(), opts()) :: result()
  def create_tweet(params, opts \\ %{}) do
    with :ok <- require_access_token(opts) do
      request(:post, "/2/tweets", put_payload(opts, tweet_payload(params)))
    end
  end

  @spec edit_tweet(String.t(), opts(), opts()) :: result()
  def edit_tweet(previous_tweet_id, params, opts \\ %{}) do
    params
    |> normalize()
    |> Map.put(:edit_options, %{previous_post_id: previous_tweet_id})
    |> create_tweet(opts)
  end

  @spec delete_tweet(String.t(), opts()) :: result()
  def delete_tweet(tweet_id, opts \\ %{}) do
    with :ok <- require_access_token(opts) do
      request(:delete, "/2/tweets/#{tweet_id}", opts)
    end
  end

  @spec get_tweet(String.t(), opts(), opts()) :: result()
  def get_tweet(tweet_id, params \\ %{}, opts \\ %{}) do
    request(:get, query_path("/2/tweets/#{tweet_id}", params), opts)
  end

  @spec quote_tweet(String.t(), String.t(), opts()) :: result()
  def quote_tweet(text, quoted_tweet_id, opts \\ %{}) do
    create_tweet(%{text: text, quote_tweet_id: quoted_tweet_id}, opts)
  end

  @spec create_thread([String.t()], opts()) :: result()
  def create_thread(texts, opts \\ %{}) when is_list(texts) do
    Enum.reduce_while(texts, {:ok, nil, []}, fn text, {:ok, previous_id, responses} ->
      params =
        if previous_id, do: %{text: text, reply_to_tweet_id: previous_id}, else: %{text: text}

      case create_tweet(params, opts) do
        {:ok, %{"data" => %{"id" => id}} = response} ->
          {:cont, {:ok, id, [response | responses]}}

        {:ok, response} ->
          {:halt,
           {:error,
            {:partial_thread_failure,
             %{reason: {:missing_tweet_id, response}, published: Enum.reverse(responses)}}}}

        {:error, reason} ->
          {:halt,
           {:error,
            {:partial_thread_failure, %{reason: reason, published: Enum.reverse(responses)}}}}
      end
    end)
    |> case do
      {:ok, _last_id, responses} -> {:ok, Enum.reverse(responses)}
      error -> error
    end
  end

  @spec search_recent(String.t(), opts(), opts()) :: result()
  def search_recent(query, params \\ %{}, opts \\ %{}) do
    request(
      :get,
      query_path("/2/tweets/search/recent", Map.put(normalize(params), :query, query)),
      opts
    )
  end

  @spec get_me(opts(), opts()) :: result()
  def get_me(params \\ %{}, opts \\ %{}),
    do: request(:get, query_path("/2/users/me", params), opts)

  @spec get_user(String.t(), opts(), opts()) :: result()
  def get_user(user_id, params \\ %{}, opts \\ %{}) do
    request(:get, query_path("/2/users/#{user_id}", params), opts)
  end

  @spec get_user_by_username(String.t(), opts(), opts()) :: result()
  def get_user_by_username(username, params \\ %{}, opts \\ %{}) do
    request(:get, query_path("/2/users/by/username/#{username}", params), opts)
  end

  @spec get_followers(String.t(), opts(), opts()) :: result()
  def get_followers(user_id, params \\ %{}, opts \\ %{}) do
    request(:get, query_path("/2/users/#{user_id}/followers", params), opts)
  end

  @spec get_following(String.t(), opts(), opts()) :: result()
  def get_following(user_id, params \\ %{}, opts \\ %{}) do
    request(:get, query_path("/2/users/#{user_id}/following", params), opts)
  end

  @spec follow_user(String.t(), String.t(), opts()) :: result()
  def follow_user(source_user_id, target_user_id, opts \\ %{}) do
    with :ok <- require_access_token(opts) do
      request(
        :post,
        "/2/users/#{source_user_id}/following",
        put_payload(opts, %{target_user_id: target_user_id})
      )
    end
  end

  @spec unfollow_user(String.t(), String.t(), opts()) :: result()
  def unfollow_user(source_user_id, target_user_id, opts \\ %{}) do
    with :ok <- require_access_token(opts) do
      request(:delete, "/2/users/#{source_user_id}/following/#{target_user_id}", opts)
    end
  end

  @spec media_upload(:init | :append | :finalize | :status, opts(), opts()) :: result()
  def media_upload(action, params, opts \\ %{})

  def media_upload(:init, params, opts) do
    with :ok <- require_access_token(opts) do
      payload =
        %{
          total_bytes: value(params, :total_bytes),
          media_type: value(params, :media_type),
          media_category: value(params, :media_category),
          additional_owners: value(params, :additional_owners),
          shared: value(params, :shared)
        }
        |> drop_nil()

      request(:post, @media_initialize_path, put_payload(opts, payload))
    end
  end

  def media_upload(:append, params, opts) do
    with :ok <- require_access_token(opts),
         :ok <- require_fields(params, [:media_id, :media]) do
      media_id = value(params, :media_id)

      fields =
        multipart_fields(%{
          segment_index: value(params, :segment_index, 0)
        }) ++ [{:media, {value(params, :media), filename: value(params, :filename, "media.bin")}}]

      request(:post, "#{@media_path}/#{media_id}/append", put_multipart(opts, fields))
    end
  end

  def media_upload(:finalize, params, opts) do
    with :ok <- require_access_token(opts),
         :ok <- require_fields(params, [:media_id]) do
      request(:post, "#{@media_path}/#{value(params, :media_id)}/finalize", opts)
    end
  end

  def media_upload(:status, params, opts) do
    with :ok <- require_access_token(opts),
         :ok <- require_fields(params, [:media_id]) do
      request(
        :get,
        query_path(@media_path, %{media_id: value(params, :media_id)}),
        opts
      )
    end
  end

  def media_upload(action, _params, _opts), do: {:error, {:unsupported_media_action, action}}

  defp require_access_token(opts) do
    opts = normalize(opts)

    case opts[:access_token] do
      token when is_binary(token) and token != "" -> :ok
      _missing -> {:error, :access_token_required}
    end
  end

  defp require_fields(opts, fields) do
    missing =
      Enum.filter(fields, fn field ->
        case opts[field] do
          value when is_binary(value) -> value == ""
          nil -> true
          _value -> false
        end
      end)

    if missing == [], do: :ok, else: {:error, {:missing_required_fields, missing}}
  end

  defp token_opts(opts, form) do
    opts
    |> Map.put(:auth, false)
    |> Map.put(:form, form)
    |> maybe_basic_auth()
  end

  defp maybe_basic_auth(%{client_id: client_id, client_secret: client_secret} = opts)
       when is_binary(client_id) and is_binary(client_secret) do
    token = Base.encode64("#{client_id}:#{client_secret}")

    Map.update(
      opts,
      :headers,
      [{"Authorization", "Basic #{token}"}],
      &[{"Authorization", "Basic #{token}"} | &1]
    )
  end

  defp maybe_basic_auth(opts), do: opts

  defp tweet_payload(params) do
    params = normalize(params)

    %{
      text: params[:text],
      reply: maybe_map(:in_reply_to_tweet_id, params[:reply_to_tweet_id]),
      quote_tweet_id: params[:quote_tweet_id],
      media: maybe_map(:media_ids, params[:media_ids]),
      edit_options: params[:edit_options]
    }
    |> drop_nil()
  end

  defp maybe_map(_key, nil), do: nil
  defp maybe_map(key, value), do: %{key => value}

  defp query_path(path, params) do
    params = normalize(params) |> encode_params()

    case URI.encode_query(params) do
      "" -> path
      query -> "#{path}?#{query}"
    end
  end

  defp encode_params(params) do
    Enum.reduce(params, %{}, fn
      {_key, nil}, acc ->
        acc

      {key, values}, acc when is_list(values) ->
        Map.put(acc, dashed_key(key), Enum.join(values, ","))

      {key, value}, acc ->
        Map.put(acc, dashed_key(key), value)
    end)
  end

  defp dashed_key(:tweet_fields), do: "tweet.fields"
  defp dashed_key(:user_fields), do: "user.fields"
  defp dashed_key(:media_fields), do: "media.fields"
  defp dashed_key(:place_fields), do: "place.fields"
  defp dashed_key(:poll_fields), do: "poll.fields"
  defp dashed_key(key), do: to_string(key)

  defp put_payload(opts, payload), do: opts |> normalize() |> Map.put(:json, payload)
  defp put_multipart(opts, fields), do: opts |> normalize() |> Map.put(:form_multipart, fields)

  defp multipart_fields(map) do
    map
    |> drop_nil()
    |> Enum.map(fn {key, value} -> {key, to_string(value)} end)
  end

  defp url(path, opts) do
    if String.starts_with?(path, "http"),
      do: path,
      else: "#{opts[:base_url] || Twitter.api_url()}#{path}"
  end

  defp headers(opts) do
    token = opts[:access_token] || opts[:bearer_token] || Twitter.bearer_token()
    base = default_content_type(opts) ++ List.wrap(opts[:headers])

    if opts[:auth] == false or is_nil(token),
      do: base,
      else: [{"Authorization", "Bearer #{token}"} | base]
  end

  defp default_content_type(%{json: _json}), do: [{"Content-Type", "application/json"}]
  defp default_content_type(_opts), do: []

  defp handle_response({:ok, %{status: status, body: body} = response}, opts)
       when status in 200..299 do
    body =
      if opts[:with_rate_limit],
        do: %{body: body, rate_limit: rate_limit(response.headers)},
        else: body

    {:ok, body}
  end

  defp handle_response({:ok, %{status: 401}}, _opts), do: {:error, :invalid_token}

  defp handle_response({:ok, %{status: 429, body: body} = response}, _opts) do
    {:error, {:rate_limited, %{body: body, rate_limit: rate_limit(response.headers)}}}
  end

  defp handle_response(
         {:ok, %{status: status, body: %{"title" => title, "detail" => detail}} = response},
         opts
       ),
       do: {:error, error_payload(status, "#{title}: #{detail}", response, opts)}

  defp handle_response({:ok, %{status: status, body: %{"detail" => detail}} = response}, opts),
    do: {:error, error_payload(status, detail, response, opts)}

  defp handle_response({:ok, %{status: status, body: %{"errors" => errors}} = response}, opts),
    do: {:error, error_payload(status, errors, response, opts)}

  defp handle_response({:ok, %{status: status, body: body} = response}, opts),
    do: {:error, error_payload(status, body, response, opts)}

  defp handle_response({:error, error}, _opts), do: {:error, error}

  defp error_payload(status, reason, response, %{with_rate_limit: true}) do
    %{status: status, reason: reason, rate_limit: rate_limit(response.headers)}
  end

  defp error_payload(status, reason, _response, _opts), do: {status, reason}

  defp rate_limit(headers) do
    reset = header(headers, "x-rate-limit-reset")
    remaining = parse_int(header(headers, "x-rate-limit-remaining"))

    %{
      limit: parse_int(header(headers, "x-rate-limit-limit")),
      remaining: remaining,
      reset: parse_int(reset),
      reset_at: unix_datetime(reset),
      retry_after: parse_int(header(headers, "retry-after")),
      rate_limited?: remaining == 0
    }
    |> drop_nil()
  end

  defp header(headers, name) do
    headers
    |> Enum.find_value(fn {key, value} -> if String.downcase(key) == name, do: value end)
    |> first_header_value()
  end

  defp first_header_value([value | _]), do: value
  defp first_header_value(value), do: value

  defp parse_int(nil), do: nil

  defp parse_int(value) when is_integer(value), do: value

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _other -> nil
    end
  end

  defp unix_datetime(nil), do: nil

  defp unix_datetime(value) do
    value
    |> parse_int()
    |> case do
      nil -> nil
      timestamp -> DateTime.from_unix!(timestamp)
    end
  end

  defp maybe_put(options, _key, nil), do: options
  defp maybe_put(options, key, value), do: Keyword.put(options, key, value)

  defp drop_nil(map), do: Map.reject(map, fn {_key, value} -> is_nil(value) end)
  defp normalize(value) when is_map(value), do: value
  defp normalize(value) when is_list(value), do: Map.new(value)

  defp value(params, key, default \\ nil), do: normalize(params) |> Map.get(key, default)

  defp encode_scope(scopes) when is_list(scopes), do: Enum.join(scopes, " ")
  defp encode_scope(scope), do: scope

  defp random_verifier do
    32
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end
end
