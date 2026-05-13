defmodule Lux.Integrations.YouTube.Client do
  @moduledoc """
  HTTP client for YouTube Data API v3 requests.

  The client supports OAuth bearer tokens, API-key reads, retryable transient
  errors, and quota/rate-limit aware error normalization.
  """

  require Logger

  alias Lux.Integrations.YouTube.RateLimit

  @endpoint "https://www.googleapis.com/youtube/v3"

  @type request_opts :: %{
          optional(:access_token) => String.t(),
          optional(:api_key) => String.t(),
          optional(:params) => map() | keyword(),
          optional(:json) => map(),
          optional(:headers) => [{String.t(), String.t()}],
          optional(:plug) => {module(), term()},
          optional(:max_retries) => non_neg_integer(),
          optional(:retry_base_delay_ms) => non_neg_integer(),
          optional(:sleep) => (non_neg_integer() -> any())
        }

  @doc """
  Makes a request to the YouTube Data API v3.
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    request_with_retry(method, path, opts, 0)
  end

  defp request_with_retry(method, path, opts, attempt) do
    case do_request(method, path, opts) do
      {:ok, %{status: status, body: body} = response} ->
        if RateLimit.retryable_response?(status, body) and attempt < option(opts, :max_retries, 2) do
          delay_ms =
            RateLimit.retry_delay_ms(response.headers, attempt,
              base_delay_ms: option(opts, :retry_base_delay_ms, 500)
            )

          Logger.debug("Retrying YouTube API request after #{delay_ms}ms",
            status: status,
            attempt: attempt + 1
          )

          sleep(opts).(delay_ms)
          request_with_retry(method, path, opts, attempt + 1)
        else
          normalize_response({:ok, response})
        end

      {:error, error} when attempt < option(opts, :max_retries, 2) ->
        delay_ms =
          RateLimit.retry_delay_ms([], attempt,
            base_delay_ms: option(opts, :retry_base_delay_ms, 500)
          )

        Logger.debug("Retrying YouTube API request after transport error",
          error: inspect(error),
          delay_ms: delay_ms,
          attempt: attempt + 1
        )

        sleep(opts).(delay_ms)
        request_with_retry(method, path, opts, attempt + 1)

      result ->
        normalize_response(result)
    end
  end

  defp do_request(method, path, opts) do
    [
      method: method,
      url: @endpoint <> path,
      headers: headers(opts),
      params: params(opts),
      json: opts[:json]
    ]
    |> Keyword.merge(req_config())
    |> maybe_add_plug(opts[:plug])
    |> Req.new()
    |> Req.request()
  end

  defp normalize_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body || %{}}
  end

  defp normalize_response({:ok, %{status: 401}}), do: {:error, :invalid_token}

  defp normalize_response({:ok, %{body: %{"error" => %{"code" => code, "message" => message} = error}}}) do
    {:error, {code, message, Map.get(error, "errors", [])}}
  end

  defp normalize_response({:ok, %{status: status, body: body}}), do: {:error, {status, body}}
  defp normalize_response({:error, error}), do: {:error, error}

  defp headers(opts) do
    [{"Accept", "application/json"}, {"Content-Type", "application/json"}]
    |> maybe_add_auth_header(opts[:access_token] || config(:access_token))
    |> Kernel.++(opts[:headers] || [])
  end

  defp maybe_add_auth_header(headers, nil), do: headers
  defp maybe_add_auth_header(headers, token), do: [{"Authorization", "Bearer #{token}"} | headers]

  defp params(opts) do
    opts
    |> option(:params, %{})
    |> put_api_key(opts[:api_key] || config(:api_key))
  end

  defp put_api_key(params, nil), do: params
  defp put_api_key(params, api_key) when is_list(params), do: Keyword.put_new(params, :key, api_key)
  defp put_api_key(params, api_key) when is_map(params), do: Map.put_new(params, :key, api_key)

  defp req_config do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.drop([:access_token, :api_key, :max_retries, :retry_base_delay_ms, :sleep])
  end

  defp option(opts, key, default) do
    case opts[key] do
      nil -> Keyword.get(Application.get_env(:lux, __MODULE__, []), key, default)
      value -> value
    end
  end

  defp config(key), do: Keyword.get(Application.get_env(:lux, __MODULE__, []), key)
  defp sleep(opts), do: option(opts, :sleep, &Process.sleep/1)

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)
end
