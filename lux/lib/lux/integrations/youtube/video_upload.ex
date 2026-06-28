defmodule Lux.Integrations.YouTube.VideoUpload do
  @moduledoc """
  Handles resumable video uploads to YouTube via the Data API v3.

  **NOTE**: This is a simplified single-PUT implementation. It does not fully 
  implement chunked resumable upload workflows, such as handling 308 
  Resume Incomplete, Content-Range headers, or retry/resume flows.
  """

  alias Lux.Integrations.YouTube.Client

  @upload_url "https://www.googleapis.com/upload/youtube/v3/videos"

  @doc """
  Initiates a resumable upload session.
  Returns `{:ok, upload_url}` or `{:error, reason}`.
  """
  def initiate_upload_session(metadata, params \\ [], config \\ Client.default_config()) do
    params =
      params
      |> Keyword.put_new(:uploadType, "resumable")
      |> Keyword.put_new(:part, "snippet,status")

    if config.dry_run do
      {:ok, %{dry_run: true, operation: :initiate_upload_session, metadata: metadata, params: params}}
    else
      headers = [
        {"X-Upload-Content-Type", "video/*"},
        {"Content-Type", "application/json"}
      ]

      headers =
        if config.access_token do
          [{"Authorization", "Bearer #{config.access_token}"} | headers]
        else
          headers
        end

      opts =
        [url: @upload_url, params: params, headers: headers]
        |> Keyword.merge(Application.get_env(:lux, Client, []))

      Req.new(opts)
      |> Req.post(json: metadata)
      |> case do
        {:ok, %{status: 200, headers: resp_headers}} ->
          # YouTube returns the resumable session URI in the Location header
          location = extract_header(resp_headers, "location")

          if location do
            {:ok, location}
          else
            {:error, "Missing Location header in response"}
          end

        {:ok, %{status: status, body: %{"error" => err}}} ->
          {:error, {status, err["message"] || inspect(err)}}

        {:ok, response} ->
          {:error, {:unexpected_status, response.status, response.body}}

        {:error, reason} ->
          {:error, {:network_error, reason}}
      end
    end
  end

  @doc """
  Uploads video data to the resumable session URL.
  This can be used to upload the entire file or a chunk.
  `video_data` is the binary content.
  """
  def upload_video_data(upload_url, video_data, config \\ Client.default_config()) do
    if config.dry_run do
      {:ok, %{dry_run: true, operation: :upload_video_data, url: upload_url, bytes: byte_size(video_data)}}
    else
      headers = [{"Content-Type", "application/octet-stream"}]

      Client.put(upload_url, video_data, headers, config)
    end
  end

  defp extract_header(headers, key) do
    headers
    |> Enum.find(fn {k, _v} -> String.downcase(k) == key end)
    |> case do
      {_, [value]} -> value
      {_, value} when is_binary(value) -> value
      _ -> nil
    end
  end
end
