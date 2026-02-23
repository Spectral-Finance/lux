defmodule Lux.Lenses.Twitter.Media.GetUploadStatus do
  @moduledoc """
  A lens for checking the processing status of uploaded media on Twitter.

  After uploading media via the chunked upload flow, use this lens to poll
  the processing status until the media is ready to attach to tweets.

  ## Authentication

  Uses OAuth 1.0a User Context authentication.

  ## Rate Limits

  No specific rate limit, but polling should be limited to avoid abuse.
  Recommended: poll every 5 seconds until `processing_info.state` is
  `"succeeded"` or `"failed"`.

  ## Examples

      iex> GetUploadStatus.focus(%{
      ...>   media_id: "710511363345354753"
      ...> })
      {:ok, %{
        media_id: "710511363345354753",
        processing_state: "succeeded",
        progress_percent: 100,
        expires_after_secs: 86400
      }}

      iex> GetUploadStatus.focus(%{
      ...>   media_id: "710511363345354753"
      ...> })
      {:ok, %{
        media_id: "710511363345354753",
        processing_state: "in_progress",
        progress_percent: 45,
        check_after_secs: 5
      }}
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Get Twitter Media Upload Status",
    description: "Checks the processing status of an uploaded media file on Twitter",
    url: "https://upload.twitter.com/1.1/media/upload.json",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.oauth1_auth(),
    schema: %{
      type: :object,
      properties: %{
        media_id: %{
          type: :string,
          description: "The media ID returned from the upload initiation"
        }
      },
      required: ["media_id"]
    }

  @impl true
  def before_focus(params) do
    media_id = params["media_id"] || params[:media_id]
    {:ok, %{"command" => "STATUS", "media_id" => media_id}}
  end

  @impl true
  def after_focus(%{"media_id_string" => media_id} = response) do
    processing = response["processing_info"] || %{}

    result = %{
      media_id: media_id,
      media_key: response["media_key"],
      processing_state: processing["state"] || "ready",
      progress_percent: processing["progress_percent"] || 100,
      expires_after_secs: response["expires_after_secs"],
      check_after_secs: get_in(processing, ["check_after_secs"])
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()

    {:ok, result}
  end

  def after_focus(%{"errors" => [%{"message" => msg} | _]}) do
    {:error, %{message: msg}}
  end

  def after_focus(response) do
    {:error, %{title: "Unexpected response", detail: inspect(response)}}
  end
end
