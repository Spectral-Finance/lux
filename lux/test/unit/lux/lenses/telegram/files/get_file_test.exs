defmodule Lux.Lenses.Telegram.Files.GetFileTest do
  @moduledoc """
  Test suite for the GetFile lens.
  Verifies:
  - Successful file info retrieval with download path
  - File without explicit size
  - Missing required params
  - Error handling (file expired, not found)
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Files.GetFile

  @file_id "BQACAgIAAxkBAAIBXl6c5ExJmN_test_file_id"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "retrieves file info with download path" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ "getFile"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "file_id" => @file_id,
            "file_unique_id" => "AgADXXXtest",
            "file_size" => 102_400,
            "file_path" => "documents/file_1234.pdf"
          }
        }))
      end)

      assert {:ok, result} = GetFile.focus(%{file_id: @file_id}, %{})
      assert result.file_id == @file_id
      assert result.file_unique_id == "AgADXXXtest"
      assert result.file_size == 102_400
      assert result.file_path == "documents/file_1234.pdf"
    end

    test "handles file without size (small files)" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "file_id" => @file_id,
            "file_unique_id" => "AgADYYYtest",
            "file_path" => "photos/file_5678.jpg"
          }
        }))
      end)

      assert {:ok, result} = GetFile.focus(%{file_id: @file_id}, %{})
      assert result.file_id == @file_id
      assert result.file_path == "photos/file_5678.jpg"
      refute Map.has_key?(result, :file_size)
    end

    test "returns error when file_id is missing" do
      assert {:error, "file_id is required"} = GetFile.focus(%{}, %{})
    end

    test "handles file not found error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: wrong file identifier/HTTP URL specified"
        }))
      end)

      assert {:error, "Bad Request: wrong file identifier/HTTP URL specified"} =
               GetFile.focus(%{file_id: "invalid_id"}, %{})
    end

    test "handles file too large error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: file is too big"
        }))
      end)

      assert {:error, "Bad Request: file is too big"} =
               GetFile.focus(%{file_id: @file_id}, %{})
    end
  end

  describe "schema validation" do
    test "requires file_id" do
      lens = GetFile.view()
      assert "file_id" in lens.schema.required
    end
  end
end
