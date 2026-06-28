defmodule Lux.Integrations.YouTube.VideoUploadTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.Client
  alias Lux.Integrations.YouTube.VideoUpload

  setup do
    Application.put_env(:lux, Client, plug: {Req.Test, Client})
    Req.Test.verify_on_exit!()
    
    %{
      config: %Client.Config{
        api_key: "test_api_key",
        access_token: nil,
        dry_run: false
      }
    }
  end

  describe "initiate_upload_session/3" do
    test "initiates a resumable upload session", %{config: config} do
      Req.Test.expect(Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/upload/youtube/v3/videos"
        assert conn.query_string =~ "uploadType=resumable"
        assert conn.query_string =~ "part=snippet%2Cstatus"
        
        # Verify custom headers
        assert ["video/*"] = Plug.Conn.get_req_header(conn, "x-upload-content-type")
        
        conn
        |> Plug.Conn.put_resp_header("location", "https://example.com/upload_session")
        |> Req.Test.json(%{})
      end)

      assert {:ok, result} = VideoUpload.initiate_upload_session(%{
        "snippet" => %{"title" => "Test Video"}
      }, [], config)
      
      assert result == "https://example.com/upload_session"
    end

    test "handles missing location header", %{config: config} do
      Req.Test.expect(Client, fn conn ->
        Req.Test.json(conn, %{})
      end)

      assert {:error, "Missing Location header in response"} = VideoUpload.initiate_upload_session(%{}, [], config)
    end
  end

  describe "upload_video_data/3" do
    test "uploads a chunk of video data", %{config: config} do
      Req.Test.expect(Client, fn conn ->
        assert conn.method == "PUT"
        assert ["application/octet-stream"] = Plug.Conn.get_req_header(conn, "content-type")
        
        Req.Test.json(conn, %{"id" => "video123"})
      end)

      assert {:ok, result} = VideoUpload.upload_video_data("https://example.com/upload", "video_data", config)
      assert result["id"] == "video123"
    end
    
    test "handles incomplete upload (308 response)", %{config: config} do
      Req.Test.expect(Client, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("range", "bytes=0-99")
        |> Plug.Conn.send_resp(308, "")
      end)

      assert {:ok, {:resume_incomplete, response}} = VideoUpload.upload_video_data("https://example.com/upload", "video_data", config)
      assert response.status == 308
    end
  end
end
