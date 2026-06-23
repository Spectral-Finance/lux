defmodule Lux.Prisms.YouTube.UploadVideoPrismTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.UploadVideoPrism

  setup do
    Application.put_env(:lux, UploadVideoPrism, plug: {Req.Test, UploadVideoPrism})
    Req.Test.verify_on_exit!()
    
    # Create a dummy file for the test
    file_path = "dummy_video_#{System.unique_integer([:positive])}.mp4"
    File.write!(file_path, "fake video content")
    
    on_exit(fn ->
      File.rm(file_path)
    end)

    {:ok, video_path: file_path}
  end

  test "simulates chunked upload sequence", %{video_path: video_path} do
    Req.Test.expect(UploadVideoPrism, 2, fn conn ->
      if conn.method == "POST" do
        assert conn.request_path == "/upload/youtube/v3/videos"
        assert conn.query_string == "uploadType=resumable&part=snippet%2Cstatus"
        
        Plug.Conn.put_resp_header(conn, "location", "https://example.com/upload?upload_id=123")
        |> Plug.Conn.send_resp(200, "")
      else
        assert conn.method == "PUT"
        assert conn.request_path == "/upload"
        assert conn.query_string == "upload_id=123"
        
        Plug.Conn.put_resp_content_type(conn, "application/json")
        |> Plug.Conn.send_resp(200, ~s({"id": "vid123"}))
      end
    end)

    result = UploadVideoPrism.handler(%{
      "video_path" => video_path,
      "access_token" => "fake_token",
      "title" => "Test",
      "description" => "Test Desc"
    }, nil)

    assert {:ok, %{video_id: "vid123"}} = result
  end

  test "handles 403 quota exceeded", %{video_path: video_path} do
    Req.Test.expect(UploadVideoPrism, fn conn ->
      Plug.Conn.put_resp_header(conn, "content-type", "application/json")
      |> Plug.Conn.send_resp(403, ~s({"error": {"errors": [{"reason": "quotaExceeded"}]}}))
    end)

    result = UploadVideoPrism.handler(%{
      "video_path" => video_path,
      "access_token" => "fake_token"
    }, nil)

    assert {:error, :quota_exceeded} = result
  end
end
