defmodule Lux.Integrations.Twitter.Client do
  @moduledoc """
  Resilient HTTP & OAuth 2.0 PKCE client for Twitter API v2 requests.

  Features:
  - OAuth 2.0 PKCE challenge/verifier generation and token refresh management
  - Automatic rate-limit header inspection (`x-rate-limit-remaining`, `x-rate-limit-reset`)
  - Structured 429 backoff diagnostics and transient retry support
  - Configurable mock plug support for 100% offline deterministic ExUnit testing
  """

  require Logger

  @endpoint "https://api.twitter.com/2"
  @oauth_token_url "https://api.twitter.com/2/oauth2/token"
  @default_max_retries 3

  @type request_opts :: %{
          optional(:token) => String.t(),
          optional(:json) => map(),
          optional(:params) => map() | keyword(),
          optional(:headers) => [{String.t(), String.t()}],
          optional(:plug) => {module(), term()},
          optional(:retry) => boolean(),
          optional(:max_retries) => non_neg_integer()
        }

  @doc """
  Generates an OAuth 2.0 PKCE code verifier and S256 code challenge pair.
  """
  @spec generate_pkce_pair() :: %{code_verifier: String.t(), code_challenge: String.t(), method: String.t()}
  def generate_pkce_pair do
    verifier =
      :crypto.strong_rand_bytes(32)
      |> Base.url_encode64(padding: false)

    challenge =
      :crypto.hash(:sha256, verifier)
      |> Base.url_encode64(padding: false)

    %{
      code_verifier: verifier,
      code_challenge: challenge,
      method: "S256"
    }
  end

  @doc """
  Exchanges an authorization code or refresh token for an OAuth 2.0 access token.
  """
  @spec exchange_oauth_token(map(), request_opts()) :: {:ok, map()} | {:error, term()}
  def exchange_oauth_token(grant_params, opts \\ %{}) when is_map(grant_params) do
    req_options =
      [
        method: :post,
        url: @oauth_token_url,
        headers: [{"Content-Type", "application/x-www-form-urlencoded"} | Map.get(opts, :headers, [])],
        form: grant_params,
        retry: false
      ]
      |> maybe_add_plug(opts[:plug])

    req_options
    |> Req.new()
    |> Req.request()
    |> handle_response()
  end

  @doc """
  Executes a Twitter API v2 request with Bearer authentication and rate-limit handling.
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    token = resolve_token(opts[:token])
    url = @endpoint <> path
    max_retries = Map.get(opts, :max_retries, @default_max_retries)

    req_options =
      [
        method: method,
        url: url,
        headers: [
          {"Content-Type", "application/json"},
          {"Authorization", "Bearer #{token}"}
          | Map.get(opts, :headers, [])
        ],
        json: opts[:json],
        params: Map.get(opts, :params, %{}),
        retry: if(Map.get(opts, :retry, true), do: :safe_transient, else: false),
        max_retries: max_retries
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
      |> maybe_add_plug(opts[:plug])

    req_options
    |> Req.new()
    |> Req.request()
    |> handle_response()
  end

  defp handle_response({:ok, %{status: status} = response}) when status in 200..299 do
    {:ok, response.body}
  end

  defp handle_response({:ok, %{status: 401}}) do
    {:error, :unauthorized}
  end

  defp handle_response({:ok, %{status: 429, headers: headers, body: body}}) do
    reset_at = extract_rate_limit_reset(headers)
    Logger.warning("Twitter API v2 rate limit reached. Reset timestamp: #{inspect(reset_at)}")
    {:error, {:rate_limited, %{reset_at: reset_at, body: body}}}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    {:error, {status, body}}
  end

  defp handle_response({:error, error}) do
    {:error, error}
  end

  defp extract_rate_limit_reset(headers) when is_map(headers) do
    case Map.get(headers, "x-rate-limit-reset") do
      [val | _] -> parse_int(val)
      val when is_binary(val) -> parse_int(val)
      _ -> nil
    end
  end

  defp extract_rate_limit_reset(headers) when is_list(headers) do
    case List.keyfind(headers, "x-rate-limit-reset", 0) do
      {_, val} -> parse_int(val)
      nil -> nil
    end
  end

  defp extract_rate_limit_reset(_), do: nil

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(_), do: nil

  defp resolve_token(token) when is_binary(token) and token != "", do: token
  defp resolve_token(_), do: Lux.Integrations.Twitter.resolve_bearer_token()

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)
end
