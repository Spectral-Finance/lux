defmodule Lux.Telegram.MediaTest do
  use UnitAPICase, async: true

  alias Lux.Telegram.Keyboards
  alias Lux.Telegram.Media

  describe "media sending functions" do
    test "send_photo with URL and with file tuple" do
      test_pid = self()

      plug = fn conn ->
        {:ok, _body, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:request, conn.request_path})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 1}}))
      end

      # String photo URL
      assert {:ok, _} =
               Media.send_photo(123, "https://example.com/pic.jpg", plug: plug, token: "tok123")

      assert_receive {:request, "/bottok123/sendPhoto"}

      # File tuple
      tmp_file = Path.join(System.tmp_dir!(), "lux_test_photo_#{System.unique_integer([:positive, :monotonic])}.jpg")
      File.write!(tmp_file, "fake_image_data")

      assert {:ok, _} =
               Media.send_photo(123, {:file, tmp_file}, %{
                 caption: "My photo",
                 reply_markup: Keyboards.inline_keyboard([[Keyboards.inline_button("Hi", "data")]]),
                 plug: plug,
                 token: "tok123"
               })

      assert_receive {:request, "/bottok123/sendPhoto"}
      File.rm(tmp_file)
    end

    test "send_document with URL and file tuple" do
      test_pid = self()

      plug = fn conn ->
        send(test_pid, {:request, conn.request_path})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 2}}))
      end

      assert {:ok, _} = Media.send_document(123, "doc_id", plug: plug, token: "tok123")
      assert_receive {:request, "/bottok123/sendDocument"}

      tmp_file = Path.join(System.tmp_dir!(), "lux_test_doc_#{System.unique_integer([:positive, :monotonic])}.pdf")
      File.write!(tmp_file, "fake_pdf")

      assert {:ok, _} = Media.send_document(123, {:file, tmp_file}, plug: plug, token: "tok123")
      assert_receive {:request, "/bottok123/sendDocument"}
      File.rm(tmp_file)
    end

    test "send_voice with URL and file tuple" do
      test_pid = self()

      plug = fn conn ->
        send(test_pid, {:request, conn.request_path})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 3}}))
      end

      assert {:ok, _} = Media.send_voice(123, "voice_id", plug: plug, token: "tok123")
      assert_receive {:request, "/bottok123/sendVoice"}
    end

    test "send_audio with URL and file tuple" do
      test_pid = self()

      plug = fn conn ->
        send(test_pid, {:request, conn.request_path})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 4}}))
      end

      assert {:ok, _} = Media.send_audio(123, "audio_id", plug: plug, token: "tok123")
      assert_receive {:request, "/bottok123/sendAudio"}
    end

    test "send_video with URL and file tuple" do
      test_pid = self()

      plug = fn conn ->
        send(test_pid, {:request, conn.request_path})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 5}}))
      end

      assert {:ok, _} = Media.send_video(123, "video_id", plug: plug, token: "tok123")
      assert_receive {:request, "/bottok123/sendVideo"}
    end
  end

  describe "get_file/2" do
    test "fetches file metadata" do
      test_pid = self()

      plug = fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        send(test_pid, {:get_file, params})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{"file_id" => "f123", "file_path" => "photos/file_1.jpg", "file_size" => 1024}
        }))
      end

      assert {:ok, %{"result" => %{"file_path" => "photos/file_1.jpg"}}} =
               Media.get_file("f123", plug: plug, token: "tok123")

      assert_receive {:get_file, %{"file_id" => "f123"}}
    end
  end

  describe "download_file/2" do
    test "downloads file directly when path is provided" do
      plug = fn conn ->
        assert conn.request_path == "/file/botmy_token/photos/file_1.jpg"

        conn
        |> Plug.Conn.put_resp_content_type("image/jpeg")
        |> Plug.Conn.send_resp(200, "binary_file_content")
      end

      assert {:ok, "binary_file_content"} =
               Media.download_file("photos/file_1.jpg", plug: plug, token: "my_token")
    end

    test "resolves file_id to file_path first when id is given" do
      plug = fn conn ->
        case conn.request_path do
          "/botmy_token/getFile" ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"file_path" => "docs/test.pdf"}}))

          "/file/botmy_token/docs/test.pdf" ->
            conn
            |> Plug.Conn.put_resp_content_type("application/pdf")
            |> Plug.Conn.send_resp(200, "pdf_bytes")
        end
      end

      assert {:ok, "pdf_bytes"} =
               Media.download_file("raw_file_id", plug: plug, token: "my_token")
    end

    test "handles 401 invalid token on download" do
      plug = fn conn ->
        Plug.Conn.send_resp(conn, 401, "Unauthorized")
      end

      assert {:error, :invalid_token} =
               Media.download_file("photos/file.jpg", plug: plug, token: "bad_token")
    end

    test "handles 429 rate limiting on download" do
      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{"parameters" => %{"retry_after" => 10}}))
      end

      assert {:error, {429, %{"parameters" => %{"retry_after" => 10}}}} =
               Media.download_file("photos/file.jpg", plug: plug, token: "tok")
    end

    test "handles 404 with description on download" do
      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"description" => "Not Found"}))
      end

      assert {:error, {404, "Not Found"}} =
               Media.download_file("photos/file.jpg", plug: plug, token: "tok")
    end

    test "handles non-200 generic error response" do
      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(500, "Server Error")
      end

      assert {:error, {500, "Server Error"}} =
               Media.download_file("photos/file.jpg", plug: plug, token: "tok")
    end

    test "handles error resolving file_id" do
      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{"ok" => false, "description" => "Bad Request"}))
      end

      assert {:error, _} =
               Media.download_file("nonexistent_id", plug: plug, token: "tok")
    end
  end

  describe "file upload and download edge cases" do
    test "send_voice, send_audio, send_video with {:file, path}" do
      test_pid = self()
      tmp_file = Path.join(System.tmp_dir!(), "lux_test_audio_#{System.unique_integer([:positive, :monotonic])}.ogg")
      File.write!(tmp_file, "fake_audio")

      plug = fn conn ->
        send(test_pid, {:request, conn.request_path})
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 1}}))
      end

      assert {:ok, _} = Media.send_voice(123, {:file, tmp_file}, plug: plug, token: "tok123")
      assert_receive {:request, "/bottok123/sendVoice"}

      assert {:ok, _} = Media.send_audio(123, {:file, tmp_file}, plug: plug, token: "tok123")
      assert_receive {:request, "/bottok123/sendAudio"}

      assert {:ok, _} = Media.send_video(123, {:file, tmp_file}, plug: plug, token: "tok123")
      assert_receive {:request, "/bottok123/sendVideo"}

      File.rm(tmp_file)
    end

    test "download_file with atom map result from get_file" do
      plug = fn conn ->
        case conn.request_path do
          "/bottok/getFile" ->
            conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{result: %{file_path: "voice/v1.ogg"}}))
          "/file/bottok/voice/v1.ogg" ->
            conn |> Plug.Conn.put_resp_content_type("audio/ogg") |> Plug.Conn.send_resp(200, "audio_data")
        end
      end

      assert {:ok, "audio_data"} = Media.download_file("file_id_123", plug: plug, token: "tok")
    end

    test "download_file handles unexpected get_file response" do
      plug = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"no_file_path" => true}}))
      end

      assert {:error, {:unexpected_response, _}} = Media.download_file("bad_file_id", plug: plug, token: "tok")
    end
  end

  describe "media error handling and edge cases" do
    test "download_file with mixed key get_file result variants" do
      # 1. %{"result" => %{file_path: "p1"}}
      plug1 = fn conn ->
        case conn.request_path do
          "/botmy_token/getFile" ->
            conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"result" => %{file_path: "p1.jpg"}}))
          "/file/botmy_token/p1.jpg" ->
            conn |> Plug.Conn.put_resp_content_type("image/jpeg") |> Plug.Conn.send_resp(200, "data1")
        end
      end
      assert {:ok, "data1"} = Media.download_file("f1", plug: plug1, token: "my_token")

      # 2. %{result: %{"file_path" => "p2"}}
      plug2 = fn conn ->
        case conn.request_path do
          "/botmy_token/getFile" ->
            conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{result: %{"file_path" => "p2.jpg"}}))
          "/file/botmy_token/p2.jpg" ->
            conn |> Plug.Conn.put_resp_content_type("image/jpeg") |> Plug.Conn.send_resp(200, "data2")
        end
      end
      assert {:ok, "data2"} = Media.download_file("f2", plug: plug2, token: "my_token")
    end

    test "download_file handles 429 with atom map parameters and network exception" do
      plug_429 = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(429, Jason.encode!(%{parameters: %{retry_after: 5}}))
      end
      assert {:error, {429, _}} = Media.download_file("photos/pic.jpg", plug: plug_429, token: "tok")

      bad_plug = fn _conn -> raise "Network down" end
      assert {:error, %RuntimeError{message: "Network down"}} = Media.download_file("photos/pic.jpg", plug: bad_plug, token: "tok")
    end

    test "media helper default arities without options" do
      Req.Test.expect(TelegramClientMock, 7, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"message_id" => 1, "file_path" => "photos/p.jpg"}}))
      end)

      assert {:ok, _} = Media.send_photo(123, "pic")
      assert {:ok, _} = Media.send_document(123, "doc")
      assert {:ok, _} = Media.send_voice(123, "voice")
      assert {:ok, _} = Media.send_audio(123, "audio")
      assert {:ok, _} = Media.send_video(123, "video")
      assert {:ok, _} = Media.get_file("f1")
      assert {:ok, _} = Media.download_file("photos/p.jpg")
    end

    test "download_file with req_options and custom timeout" do
      plug = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("image/jpeg") |> Plug.Conn.send_resp(200, "bytes")
      end

      assert {:ok, "bytes"} = Media.download_file("photos/p.jpg", token: "tok", plug: plug, req_options: [receive_timeout: 10_000])
    end

    test "download_file with atom map result from get_file and unexpected response" do
      plug_atom = fn conn ->
        case conn.request_path do
          "/bottok/getFile" ->
            conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{result: %{file_path: "voice/v1.ogg"}}))
          "/file/bottok/voice/v1.ogg" ->
            conn |> Plug.Conn.put_resp_content_type("audio/ogg") |> Plug.Conn.send_resp(200, "audio_data")
        end
      end
      assert {:ok, "audio_data"} = Media.download_file("file_id_123", plug: plug_atom, token: "tok")

      plug_unexp = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"no_file_path" => true}}))
      end
      assert {:error, {:unexpected_response, _}} = Media.download_file("bad_file_id", plug: plug_unexp, token: "tok")

      plug_401 = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(401, Jason.encode!(%{"ok" => false}))
      end
      assert {:error, :invalid_token} = Media.download_file("photos/p.jpg", plug: plug_401, token: "tok")

      plug_500 = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(500, Jason.encode!(%{"description" => "Internal"}))
      end
      assert {:error, {500, "Internal"}} = Media.download_file("photos/p.jpg", plug: plug_500, token: "tok")

      plug_500_raw = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("text/plain") |> Plug.Conn.send_resp(500, "Server Error")
      end
      assert {:error, {500, "Server Error"}} = Media.download_file("photos/p.jpg", plug: plug_500_raw, token: "tok")

      plug_get_file_err = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(404, Jason.encode!(%{"ok" => false, "description" => "Not Found"}))
      end
      assert {:error, {404, "Not Found"}} = Media.download_file("nonexistent_id", plug: plug_get_file_err, token: "tok")

      plug_429_str = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(429, Jason.encode!(%{"parameters" => %{"retry_after" => 3}}))
      end
      assert {:error, {429, _}} = Media.download_file("photos/p.jpg", plug: plug_429_str, token: "tok")
    end
  end
end



