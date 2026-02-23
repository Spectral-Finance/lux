defmodule Lux.Lenses.Twitter.Media.GetUploadStatusTest do
  @moduledoc """
  Test suite for the Twitter GetUploadStatus lens.
  Verifies:
  - Completed upload status retrieval
  - In-progress processing status
  - Failed processing status
  - API error handling
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Twitter.Media.GetUploadStatus

  @media_id "710511363345354753"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "retrieves succeeded processing status" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ "media/upload"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "media_id_string" => @media_id,
          "media_key" => "7_#{@media_id}",
          "expires_after_secs" => 86400,
          "processing_info" => %{
            "state" => "succeeded",
            "progress_percent" => 100
          }
        }))
      end)

      assert {:ok, result} = GetUploadStatus.focus(%{"media_id" => @media_id}, %{})
      assert result.media_id == @media_id
      assert result.processing_state == "succeeded"
      assert result.progress_percent == 100
      assert result.expires_after_secs == 86400
    end

    test "retrieves in-progress processing status" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "media_id_string" => @media_id,
          "processing_info" => %{
            "state" => "in_progress",
            "progress_percent" => 45,
            "check_after_secs" => 5
          }
        }))
      end)

      assert {:ok, result} = GetUploadStatus.focus(%{"media_id" => @media_id}, %{})
      assert result.processing_state == "in_progress"
      assert result.progress_percent == 45
      assert result.check_after_secs == 5
    end

    test "retrieves failed processing status" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "media_id_string" => @media_id,
          "processing_info" => %{
            "state" => "failed",
            "progress_percent" => 0,
            "error" => %{
              "code" => 3,
              "name" => "InvalidMedia",
              "message" => "media type unrecognized"
            }
          }
        }))
      end)

      assert {:ok, result} = GetUploadStatus.focus(%{"media_id" => @media_id}, %{})
      assert result.processing_state == "failed"
      assert result.progress_percent == 0
    end

    test "handles API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "errors" => [%{"message" => "Media not found", "code" => 34}]
        }))
      end)

      assert {:error, %{message: "Media not found"}} =
               GetUploadStatus.focus(%{"media_id" => "nonexistent"}, %{})
    end
  end
end
