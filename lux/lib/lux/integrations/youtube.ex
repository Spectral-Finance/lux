defmodule Lux.Integrations.YouTube do
  @moduledoc """
  Shared YouTube Data API and Analytics API integration settings.
  """

  @data_api_base_url "https://www.googleapis.com/youtube/v3"
  @analytics_api_base_url "https://youtubeanalytics.googleapis.com/v2"
  @default_scopes [
    "https://www.googleapis.com/auth/youtube.readonly",
    "https://www.googleapis.com/auth/yt-analytics.readonly"
  ]

  @doc """
  Returns the configured YouTube Data API base URL.
  """
  def data_api_base_url do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:data_api_base_url, @data_api_base_url)
  end

  @doc """
  Returns the configured YouTube Analytics API base URL.
  """
  def analytics_api_base_url do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:analytics_api_base_url, @analytics_api_base_url)
  end

  @doc """
  Returns default OAuth scopes for channel analytics.
  """
  def default_scopes, do: @default_scopes

  @doc """
  Returns the configured API key, if present.
  """
  def api_key do
    :lux
    |> Application.get_env(:api_keys, [])
    |> Keyword.get(:google_youtube)
  end

  @doc """
  Returns default JSON headers.
  """
  def headers do
    [
      {"Accept", "application/json"}
    ]
  end

  @doc """
  Normalizes YouTube/Google API errors.
  """
  def classify_error(status, body) do
    message = error_message(body)

    case status do
      400 -> {:bad_request, message}
      401 -> :invalid_token
      403 -> {:forbidden, message}
      404 -> {:not_found, message}
      429 -> {:rate_limited, message}
      _ -> {status, message}
    end
  end

  defp error_message(%{"error" => %{"message" => message}}) when is_binary(message), do: message
  defp error_message(%{"message" => message}) when is_binary(message), do: message
  defp error_message(%{error: %{message: message}}) when is_binary(message), do: message
  defp error_message(message) when is_binary(message), do: message
  defp error_message(body), do: inspect(body)
end
