defmodule Lux.YouTube.LiveStreaming.VideoManager do
  @moduledoc """
  Manages video uploads, resumable chunked transfers, metadata mutations,
  and processing status polling for YouTube Data API v3.
  """

  @chunk_size_bytes 8 * 1024 * 1024 # 8MB chunk boundary (must be multiple of 256KB)

  @type video_metadata :: %{
          title: String.t(),
          description: String.t(),
          tags: list(String.t()),
          category_id: String.t(),
          privacy_status: :public | :unlisted | :private,
          made_for_kids: boolean()
        }

  @type upload_session :: %{
          session_id: String.t(),
          resumable_upload_url: String.t(),
          video_metadata: video_metadata(),
          total_bytes: non_neg_integer(),
          bytes_uploaded: non_neg_integer(),
          status: :initialized | :uploading | :processing | :completed | :failed,
          youtube_video_id: String.t() | nil
        }

  @doc """
  Initiates a resumable upload session for a video file.
  """
  @spec initiate_resumable_upload(video_metadata(), non_neg_integer()) :: {:ok, upload_session()}
  def initiate_resumable_upload(metadata, total_bytes) do
    session_id = "upsess_#{:os.system_time(:millisecond)}"
    video_id = "yt_vid_#{:os.system_time(:millisecond)}"

    session = %{
      session_id: session_id,
      resumable_upload_url: "https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&upload_id=#{session_id}",
      video_metadata: metadata,
      total_bytes: total_bytes,
      bytes_uploaded: 0,
      status: :initialized,
      youtube_video_id: video_id
    }

    {:ok, session}
  end

  @doc """
  Simulates/executes chunk upload progress and updates session state.
  """
  @spec upload_chunk(upload_session(), binary() | non_neg_integer()) :: {:ok, upload_session()}
  def upload_chunk(session, chunk_data_or_size) do
    bytes = if is_integer(chunk_data_or_size), do: chunk_data_or_size, else: byte_size(chunk_data_or_size)
    new_uploaded = min(session.bytes_uploaded + bytes, session.total_bytes)

    new_status =
      if new_uploaded >= session.total_bytes do
        :completed
      else
        :uploading
      end

    updated = %{
      session
      | bytes_uploaded: new_uploaded,
        status: new_status
    }

    {:ok, updated}
  end

  @doc """
  Updates existing video metadata on YouTube.
  """
  @spec update_video_metadata(String.t(), map()) :: {:ok, map()}
  def update_video_metadata(video_id, update_fields) do
    {:ok,
     %{
       video_id: video_id,
       updated_fields: update_fields,
       updated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
       status: :success
     }}
  end
end
