defmodule Lux.Integrations.Twitter do
  @moduledoc """
  Shared Twitter/X API v2 integration settings and response helpers.

  The client module uses the current X API host by default and keeps tokens in
  caller configuration instead of module state.
  """

  @default_api_base_url "https://api.x.com"
  @default_authorize_url "https://x.com/i/oauth2/authorize"
  @default_scopes ~w[tweet.read tweet.write users.read follows.read follows.write media.write offline.access]

  @type rate_limit :: %{
          limit: non_neg_integer() | nil,
          remaining: non_neg_integer() | nil,
          reset: non_neg_integer() | nil,
          reset_at: DateTime.t() | nil
        }

  @doc """
  Returns the configured API base URL.
  """
  @spec api_base_url() :: String.t()
  def api_base_url do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:api_base_url, @default_api_base_url)
  end

  @doc """
  Returns the configured OAuth authorization URL.
  """
  @spec authorize_url() :: String.t()
  def authorize_url do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:authorize_url, @default_authorize_url)
  end

  @doc """
  Returns the default OAuth scopes for user-context tweet and follow actions.
  """
  @spec default_scopes() :: [String.t()]
  def default_scopes, do: @default_scopes

  @doc """
  Returns the configured Twitter/X bearer token.
  """
  @spec bearer_token() :: String.t()
  def bearer_token do
    :lux
    |> Application.fetch_env!(:api_keys)
    |> Keyword.get(:twitter_bearer)
    |> case do
      nil -> raise "twitter_bearer is not configured in :api_keys!"
      token -> token
    end
  end

  @doc """
  Returns default JSON headers.
  """
  @spec headers() :: [{String.t(), String.t()}]
  def headers do
    [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"}
    ]
  end

  @doc """
  Returns bearer auth metadata for modules that use integration descriptors.
  """
  @spec auth() :: map()
  def auth do
    %{
      type: :bearer,
      token: &__MODULE__.bearer_token/0
    }
  end

  @doc """
  Parses X rate-limit response headers.
  """
  @spec rate_limit([{String.t(), String.t()}] | map()) :: rate_limit()
  def rate_limit(headers) do
    normalized = normalize_headers(headers)
    reset = parse_integer(Map.get(normalized, "x-rate-limit-reset"))

    %{
      limit: parse_integer(Map.get(normalized, "x-rate-limit-limit")),
      remaining: parse_integer(Map.get(normalized, "x-rate-limit-remaining")),
      reset: reset,
      reset_at: reset_at(reset)
    }
  end

  @doc """
  Converts HTTP error responses into stable atoms/tuples for callers.
  """
  @spec classify_error(non_neg_integer(), term(), [{String.t(), String.t()}] | map()) :: term()
  def classify_error(status, body, headers \\ []) do
    case status do
      400 -> {:bad_request, error_message(body)}
      401 -> :invalid_token
      403 -> {:forbidden, error_message(body)}
      404 -> {:not_found, error_message(body)}
      409 -> {:conflict, error_message(body)}
      422 -> {:unprocessable_entity, error_message(body)}
      429 -> {:rate_limited, rate_limit(headers)}
      _ -> {status, error_message(body)}
    end
  end

  defp normalize_headers(headers) when is_map(headers) do
    Map.new(headers, fn {key, value} ->
      {String.downcase(to_string(key)), header_value(value)}
    end)
  end

  defp normalize_headers(headers) when is_list(headers) do
    Map.new(headers, fn {key, value} ->
      {String.downcase(to_string(key)), header_value(value)}
    end)
  end

  defp normalize_headers(_headers), do: %{}

  defp header_value([value | _]), do: to_string(value)
  defp header_value(value) when is_binary(value), do: value
  defp header_value(value), do: to_string(value)

  defp parse_integer(nil), do: nil

  defp parse_integer(value) when is_integer(value), do: value

  defp parse_integer(value) do
    case Integer.parse(to_string(value)) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

  defp reset_at(nil), do: nil

  defp reset_at(unix_seconds) do
    case DateTime.from_unix(unix_seconds) do
      {:ok, datetime} -> datetime
      _ -> nil
    end
  end

  defp error_message(%{"detail" => detail}) when is_binary(detail), do: detail
  defp error_message(%{"message" => message}) when is_binary(message), do: message
  defp error_message(%{"title" => title}) when is_binary(title), do: title
  defp error_message(%{"errors" => [error | _]}), do: error_message(error)
  defp error_message(%{detail: detail}) when is_binary(detail), do: detail
  defp error_message(%{message: message}) when is_binary(message), do: message
  defp error_message(message) when is_binary(message), do: message
  defp error_message(nil), do: "Twitter API request failed"
  defp error_message(body), do: inspect(body)
end
