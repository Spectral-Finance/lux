defmodule Lux.Integrations.Youtube.Client do
  @moduledoc """
  HTTP client for YouTube Data API v3 and YouTube Analytics API requests.
  """

  require Logger
  alias Lux.Integrations.YoutubeAnalytics

  @data_endpoint "https://www.googleapis.com/youtube/v3"
  @analytics_endpoint "https://youtubeanalytics.googleapis.com/v2"

  @type request_opts :: %{
    optional(:token) => String.t(),
    optional(:api_key) => String.t(),
    optional(:json) => map(),
    optional(:headers) => [{String.t(), String.t()}],
    optional(:params) => map()
  }

  @doc """
  Makes a request to the YouTube Data API v3.

  ## Examples

      iex> Youtube.Client.request(:get, "/channels", %{params: %{part: "snippet", mine: true}})
      {:ok, %{"items" => [%{"id" => "123", "snippet" => %{}}]}}
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    token = opts[:token] || YoutubeAnalytics.youtube_oauth_token()
    api_key = opts[:api_key] || YoutubeAnalytics.youtube_api_key()

    headers = [{"Content-Type", "application/json"}] ++ (opts[:headers] || [])
    headers = if token, do: headers ++ [{"Authorization", "Bearer #{token}"}], else: headers

    url = build_url(@data_endpoint, path, api_key, opts[:params])

    make_request(method, url, headers, opts[:json])
  end

  @doc """
  Makes a request to the YouTube Analytics API.
  """
  @spec analytics_request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def analytics_request(method, path, opts \\ %{}) do
    token = opts[:token] || YoutubeAnalytics.youtube_oauth_token()
    headers = [{"Content-Type", "application/json"}]
    headers = if token, do: headers ++ [{"Authorization", "Bearer #{token}"}], else: headers

    url = build_url(@analytics_endpoint, path, nil, opts[:params])

    make_request(method, url, headers, opts[:json])
  end

  defp build_url(base, path, nil, nil), do: "#{base}#{path}"
  defp build_url(base, path, nil, params) when is_map(params), do: "#{base}#{path}?#{encode_params(params)}"
  defp build_url(base, path, api_key, nil), do: "#{base}#{path}?key=#{api_key}"
  defp build_url(base, path, api_key, params) when is_map(params), do: "#{base}#{path}?key=#{api_key}&#{encode_params(params)}"

  defp encode_params(params) do
    params
    |> Enum.map(fn {k, v} -> "#{URI.encode_www_form(to_string(k))}=#{URI.encode_www_form(to_string(v))}" end)
    |> Enum.join("&")
  end

  defp make_request(method, url, headers, nil) do
    http_client().request(method, url, headers, "", [])
  end

  defp make_request(method, url, headers, body) do
    encoded = Jason.encode!(body)
    http_client().request(method, url, headers, encoded, [])
  end

  defp http_client, do: Application.get_env(:lux, :http_client, Req)
end
