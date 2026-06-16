defmodule Lux.Lenses.Telegram.GetFileTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Telegram.GetFile

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully gets file info" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/bottest_telegram_bot_token/getFile"

        query = URI.decode_query(conn.query_string)
        assert query["file_id"] == "file_123"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "file_id" => "file_123",
            "file_size" => 1024,
            "file_path" => "photos/file_0.jpg"
          }
        }))
      end)

      assert {:ok, file_info} = GetFile.focus(%{file_id: "file_123"})
      assert file_info["file_id"] == "file_123"
      assert file_info["file_path"] == "photos/file_0.jpg"
    end

    test "handles error response" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "description" => "File not found"
        }))
      end)

      assert {:error, "File not found"} = GetFile.focus(%{file_id: "file_123"})
    end

    test "handles unexpected response format" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "weird" => "format"
        }))
      end)

      assert {:error, "Unexpected response format: " <> _} = GetFile.focus(%{file_id: "file_123"})
    end

    test "handles missing required parameter" do
      # Note: schema validation is usually performed by the user/agent or lens framework if enabled.
      # Let's ensure the lens requires file_id.
      lens = GetFile.view()
      assert lens.schema.required == ["file_id"]
    end
  end
end
