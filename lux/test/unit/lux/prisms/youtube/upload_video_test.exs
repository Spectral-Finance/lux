defmodule Lux.Prisms.YouTube.UploadVideoTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.YouTube.UploadVideo
  alias Lux.Integrations.YouTube.Client

  setup do
    Application.put_env(:lux, Client, plug: {Req.Test, Client})
    Application.put_env(:lux, :api_keys, [youtube_api_key: "test_api_key"])
    Req.Test.verify_on_exit!()
    
    # Create a temporary file for testing
    tmp_dir = System.tmp_dir!()
    file_path = Path.join(tmp_dir, "test_video.mp4")
    File.write!(file_path, "dummy video content")
    
    on_exit(fn -> File.rm(file_path) end)
    
    %{file_path: file_path}
  end

  describe "handler/2" do
    test "initiates upload session and uploads video file" do
      # Mock the session initiation request
      Req.Test.expect(Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/upload/youtube/v3/videos"
        
        conn
        |> Plug.Conn.put_resp_header("location", "https://example.com/upload_session")
        |> Req.Test.json(%{})
      end)

      # Mock the chunk upload request
      Req.Test.expect(Client, fn conn ->
        assert conn.method == "PUT"
        # In actual test, the path might be handled differently depending on the plug setup
        assert ["application/octet-stream"] = Plug.Conn.get_req_header(conn, "content-type")
        
        {:ok, body, _} = Plug.Conn.read_body(conn)
        assert body == "dummy video content"
        
        Req.Test.json(conn, %{"id" => "video123", "status" => %{"uploadStatus" => "uploaded"}})
      end)

      params = %{
        video_data_base64: Base.encode64("dummy video content"),
        title: "Test Video",
        description: "A test video upload",
        dry_run: false
      }
      
      assert {:ok, result} = UploadVideo.handler(params, nil)
      assert result.video_id == "video123"
    end
  end
end
