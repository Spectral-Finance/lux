defmodule Lux.Integrations.YouTube.Client do
  @moduledoc """
  HTTP client for YouTube Data API v3, OAuth2 token, and resumable upload requests.
  """

  alias Lux.Integrations.YouTube

  @type request_opts :: keyword() | map()

  @spec request(atom(), String.t(), request_opts()) :: {:ok, map() | list()} | {:error, term()}
  def request(method, path, opts \\ []) do
    case raw_request(method, path, opts) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body || %{}}

      {:ok, %{status: 401}} ->
        {:error, :invalid_token}

      {:ok, %{status: status, body: %{"error" => %{"message" => message, "errors" => errors}}}} ->
        {:error, {status, message, errors}}

      {:ok, %{status: status, body: %{"error" => %{"message" => message}}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end

  @spec raw_request(atom(), String.t(), request_opts()) ::
          {:ok, Req.Response.t()} | {:error, term()}
  def raw_request(method, path, opts \\ []) do
    opts = normalize_opts(opts)

    [
      method: method,
      url: endpoint(opts[:base]) <> path,
      headers: build_headers(opts),
      params: opts[:params] || %{}
    ]
    |> maybe_put(:json, opts[:json])
    |> maybe_put(:form, opts[:form])
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(opts[:plug])
    |> Req.new()
    |> Req.request()
  end

  def response_header(%{headers: headers}, name) do
    target = String.downcase(name)

    Enum.find_value(headers, fn {key, values} ->
      if String.downcase(to_string(key)) == target do
        values |> List.wrap() |> List.first()
      end
    end)
  end

  defp endpoint(:upload), do: YouTube.upload_endpoint()
  defp endpoint(:oauth), do: YouTube.oauth_token_endpoint()
  defp endpoint(_), do: YouTube.api_endpoint()

  defp build_headers(opts) do
    [{"Accept", "application/json"}]
    |> maybe_add_content_type(opts)
    |> maybe_add_authorization(opts)
    |> Kernel.++(opts[:headers] || [])
  end

  defp maybe_add_content_type(headers, opts) do
    cond do
      opts[:form] -> headers
      opts[:json] -> headers ++ [{"Content-Type", "application/json"}]
      true -> headers
    end
  end

  defp maybe_add_authorization(headers, opts) do
    if opts[:auth] == false do
      headers
    else
      token = opts[:token] || Lux.Config.youtube_access_token()
      headers ++ [{"Authorization", "Bearer #{token}"}]
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)

  defp normalize_opts(opts) when is_map(opts), do: Map.to_list(opts)
  defp normalize_opts(opts) when is_list(opts), do: opts
end
