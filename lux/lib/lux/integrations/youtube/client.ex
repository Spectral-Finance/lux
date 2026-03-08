defmodule Lux.Integrations.YouTube.Client do
  @moduledoc """
  HTTP client for YouTube Data API v3 with OAuth2 authentication.
  """

  alias Lux.Integrations.YouTube

  @spec request(atom(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    auth_type = opts[:auth_type] || :api_key
    params = opts[:params] || %{}
    json = opts[:json]
    base_url = opts[:base_url] || YouTube.base_url()

    url = "#{base_url}#{path}"

    {url, headers} = case auth_type do
      :api_key ->
        sep = if String.contains?(url, "?"), do: "&", else: "?"
        {url <> "#{sep}key=#{YouTube.api_key()}", []}
      :oauth2 ->
        token = opts[:access_token] || ""
        {url, [{"authorization", "Bearer #{token}"}]}
    end

    url = if map_size(params) > 0 do
      sep = if String.contains?(url, "?"), do: "&", else: "?"
      url <> sep <> URI.encode_query(params)
    else
      url
    end

    req_opts = [method: method, url: url, headers: headers, retry: false]
    req_opts = if json, do: Keyword.put(req_opts, :json, json), else: req_opts
    req_opts = Keyword.merge(req_opts, Application.get_env(:lux, __MODULE__, []))

    if opts[:plug] do
      req_opts = Keyword.put(req_opts, :plug, opts[:plug])
    end

    req_opts
    |> Req.new()
    |> Req.request()
    |> handle_response()
  end

  defp handle_response({:ok, %{status: s, body: body}}) when s in 200..299 do
    body = if is_binary(body), do: Jason.decode!(body), else: body
    {:ok, body}
  end

  defp handle_response({:ok, %{status: 401, body: body}}) do
    {:error, :unauthorized}
  end

  defp handle_response({:ok, %{status: 403, body: body}}) do
    msg = extract_error(body)
    {:error, {:forbidden, msg}}
  end

  defp handle_response({:ok, %{status: 429}}) do
    {:error, :rate_limited}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    msg = extract_error(body)
    {:error, {status, msg}}
  end

  defp handle_response({:error, error}), do: {:error, error}

  defp extract_error(%{"error" => %{"message" => msg}}), do: msg
  defp extract_error(%{"error" => %{"errors" => [%{"message" => msg} | _]}}), do: msg
  defp extract_error(body) when is_binary(body), do: body
  defp extract_error(body), do: inspect(body)

  @doc "Refresh OAuth2 access token using refresh token."
  @spec refresh_access_token(map()) :: {:ok, String.t()} | {:error, term()}
  def refresh_access_token(opts \\ %{}) do
    json = %{
      client_id: opts[:client_id] || YouTube.client_id(),
      client_secret: opts[:client_secret] || YouTube.client_secret(),
      refresh_token: opts[:refresh_token] || YouTube.refresh_token(),
      grant_type: "refresh_token"
    }

    req_opts = [method: :post, url: YouTube.oauth_token_url(), json: json, retry: false]
    req_opts = Keyword.merge(req_opts, Application.get_env(:lux, __MODULE__, []))
    if opts[:plug], do: req_opts = Keyword.put(req_opts, :plug, opts[:plug])

    case Req.new(req_opts) |> Req.request() do
      {:ok, %{status: 200, body: %{"access_token" => token}}} -> {:ok, token}
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        case Jason.decode(body) do
          {:ok, %{"access_token" => token}} -> {:ok, token}
          _ -> {:error, "Unexpected response"}
        end
      {:ok, %{status: s, body: body}} -> {:error, {s, extract_error(body)}}
      {:error, e} -> {:error, e}
    end
  end
end
