defmodule Lux.Integrations.YouTube.Client do
  @moduledoc """
  Core YouTube Data API v3 client.

  Handles OAuth2 / API Key authentication, standard error boundaries, dry runs,
  and base URL generation.

  **NOTE**: This is a static-token helper slice for YouTube integration, rather 
  than a complete OAuth2 implementation. Token lifecycle (exchange, refresh) 
  must be managed externally.
  """

  @base_url "https://www.googleapis.com/youtube/v3"

  defmodule Config do
    @moduledoc "Configuration for YouTube API"
    @type t :: %__MODULE__{
            api_key: String.t() | nil,
            access_token: String.t() | nil,
            dry_run: boolean()
          }

    defstruct api_key: nil,
              access_token: nil,
              dry_run: false
  end

  @doc """
  Executes a GET request to the YouTube API.
  """
  def get(path, params, config \\ default_config()) do
    opts = build_opts(path, params, config)

    Req.new(opts)
    |> Req.get()
    |> handle_response()
  end

  @doc """
  Executes a POST request to the YouTube API. Checks for dry_run to prevent accidental mutations.
  """
  def post(path, body, params \\ [], config \\ default_config()) do
    if config.dry_run do
      {:ok, %{dry_run: true, path: path, body: body, params: params}}
    else
      opts = build_opts(path, params, config)

      Req.new(opts)
      |> Req.post(json: body)
      |> handle_response()
    end
  end

  @doc """
  Executes a PUT request. Used for resumable video uploads.
  """
  def put(url, body, headers \\ [], config \\ default_config()) do
    if config.dry_run do
      {:ok, %{dry_run: true, url: url}}
    else
      opts = build_opts(url, [], config, true)

      Req.new(opts)
      |> Req.put(body: body, headers: headers)
      |> handle_response()
    end
  end

  @doc """
  Executes a DELETE request.
  """
  def delete(path, params \\ [], config \\ default_config()) do
    if config.dry_run do
      {:ok, %{dry_run: true, path: path, params: params}}
    else
      opts = build_opts(path, params, config)

      Req.new(opts)
      |> Req.delete()
      |> handle_response()
    end
  end

  def default_config do
    %Config{
      api_key: Application.get_env(:lux, :api_keys)[:youtube_api_key],
      access_token: Application.get_env(:lux, :api_keys)[:youtube_access_token],
      dry_run: Application.get_env(:lux, __MODULE__)[:dry_run] || false
    }
  end

  defp build_opts(path_or_url, params, config, absolute? \\ false) do
    url =
      if absolute? or String.starts_with?(path_or_url, "http") do
        path_or_url
      else
        @base_url <> path_or_url
      end

    headers =
      if config.access_token do
        [{"Authorization", "Bearer #{config.access_token}"}]
      else
        []
      end

    # Default to passing API key if available and no access token is used (or even as fallback)
    params =
      if is_nil(config.access_token) and not is_nil(config.api_key) do
        Keyword.put(params, :key, config.api_key)
      else
        params
      end

    [
      url: url,
      params: params,
      headers: headers
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
  end

  defp handle_response({:ok, %{status: status} = response}) when status in 200..299 do
    {:ok, response.body}
  end

  # Special case for YouTube Resumable Uploads which return 308 (Resume Incomplete)
  defp handle_response({:ok, %{status: 308} = response}) do
    {:ok, {:resume_incomplete, response}}
  end

  defp handle_response({:ok, %{status: 401} = response}) do
    {:error, :unauthorized, response.body}
  end

  defp handle_response({:ok, %{status: status, body: %{"error" => err}}}) do
    {:error, {status, err["message"] || inspect(err)}}
  end

  defp handle_response({:ok, response}) do
    {:error, {:unexpected_status, response.status, response.body}}
  end

  defp handle_response({:error, reason}) do
    {:error, {:network_error, reason}}
  end
end
