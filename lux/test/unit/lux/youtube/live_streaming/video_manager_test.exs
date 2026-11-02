defmodule Lux.YouTube.LiveStreaming.VideoManagerTest do
  use UnitCase, async: true

  alias Lux.YouTube.LiveStreaming.VideoManager

  describe "initiate_resumable_upload/2 and upload_chunk/2" do
    test "initiates upload session and tracks chunk upload progress" do
      metadata = %{
        title: "Scaling Distributed AI with Lux",
        description: "Complete guide",
        tags: ["elixir", "lux"],
        category_id: "28",
        privacy_status: :public,
        made_for_kids: false
      }
      total_bytes = 16 * 1024 * 1024 # 16MB

      {:ok, session} = VideoManager.initiate_resumable_upload(metadata, total_bytes)

      assert session.status == :initialized
      assert session.bytes_uploaded == 0
      assert is_binary(session.resumable_upload_url)
      assert is_binary(session.youtube_video_id)

      # Upload 8MB chunk
      {:ok, step1} = VideoManager.upload_chunk(session, 8 * 1024 * 1024)
      assert step1.bytes_uploaded == 8 * 1024 * 1024
      assert step1.status == :uploading

      # Upload remaining 8MB chunk
      {:ok, step2} = VideoManager.upload_chunk(step1, 8 * 1024 * 1024)
      assert step2.bytes_uploaded == total_bytes
      assert step2.status == :completed
    end
  end

  describe "update_video_metadata/2" do
    test "patches video metadata and returns confirmation" do
      {:ok, result} = VideoManager.update_video_metadata("vid_123", %{title: "New Title"})

      assert result.video_id == "vid_123"
      assert result.updated_fields.title == "New Title"
      assert result.status == :success
    end
  end
end
