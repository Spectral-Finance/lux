defmodule Lux.Prisms.YouTube.Videos.StartResumableUploadTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.YouTube.Videos.StartResumableUpload

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "accepts JSON-style string keys from runtime invocation" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)

      assert decoded["snippet"]["title"] == "Runtime title"
      assert decoded["status"]["privacyStatus"] == "unlisted"

      conn
      |> Plug.Conn.put_resp_header("location", "https://upload.youtube.test/session/2")
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{}))
    end)

    assert {:ok, %{session_url: "https://upload.youtube.test/session/2"}} =
             StartResumableUpload.handler(
               %{
                 "access_token" => "runtime-token",
                 "title" => "Runtime title",
                 "privacy_status" => "unlisted",
                 "plug" => {Req.Test, YouTubeClientMock}
               },
               %{name: "TestAgent"}
             )
  end
end
