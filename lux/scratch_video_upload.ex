defmodule Lux.Integrations.YouTube.VideoUpload do
  @moduledoc """
  Handles resumable video uploads to YouTube via the Data API v3.
  """

  alias Lux.Integrations.YouTube.Client

  @upload_url "https://www.googleapis.com/upload/youtube/v3/videos"

  @doc """
  Initiates a resumable upload session.
  Returns `{:ok, upload_url}` or `{:error, reason}`.
  """
  def initiate_upload_session(metadata, params \\ [], config \\ Client.default_config()) do
    # Ensures we specify uploadType=resumable and part=snippet,status
    params =
      params
      |> Keyword.put_new(:uploadType, "resumable")
      |> Keyword.put_new(:part, "snippet,status")

    if config.dry_run do
      {:ok, %{dry_run: true, operation: :initiate_upload_session, metadata: metadata, params: params}}
    else
      opts = Client.default_config() |> Map.merge(config)
      headers = [{"X-Upload-Content-Type", "video/*"}]

      # The initial POST request creates the session, the body contains the metadata
      case Client.post(@upload_url, metadata, params, %{opts | absolute_url?: true} |> Map.put(:headers, headers)) do
        # This will be routed through the default client which may not be fully optimized for this specific endpoint headers, so let's bypass it slightly if needed. Wait, Client.post doesn't support custom headers easily unless we pass them through application env. Let's write a targeted Req call here.
      end
    end
  end
end
