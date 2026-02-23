defmodule Lux.Prisms.Twitter.Media.UploadMediaTest do
  @moduledoc """
  Test suite for the Twitter UploadMedia prism.
  Verifies:
  - Successful image upload through INIT/APPEND/FINALIZE flow
  - Video upload (requires_processing: true)
  - Validation of required parameters
  - Error handling when upload fails
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Twitter.Media.UploadMedia

  @small_image Base.encode64("fake_jpeg_data_for_testing")
  @media_id "710511363345354753"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully uploads an image through INIT/APPEND/FINALIZE" do
      # INIT
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(202, Jason.encode!(%{
          "media_id_string" => @media_id,
          "expires_after_secs" => 86400
        }))
      end)

      # APPEND
      Req.Test.expect(Lux.Lens, fn conn ->
        conn |> Plug.Conn.send_resp(204, "")
      end)

      # FINALIZE
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "media_id_string" => @media_id,
          "media_key" => "7_#{@media_id}",
          "expires_after_secs" => 86400
        }))
      end)

      assert {:ok, result} = UploadMedia.handler(
        %{"media_data" => @small_image, "media_type" => "image/jpeg"},
        %{}
      )

      assert result.media_id == @media_id
      assert result.media_type == "image/jpeg"
      assert result.requires_processing == false
    end

    test "marks video uploads as requiring async processing" do
      video_data = Base.encode64("fake_mp4_data")

      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(202, Jason.encode!(%{"media_id_string" => @media_id}))
      end)

      Req.Test.expect(Lux.Lens, fn conn ->
        conn |> Plug.Conn.send_resp(204, "")
      end)

      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "media_id_string" => @media_id,
          "processing_info" => %{"state" => "pending", "check_after_secs" => 5}
        }))
      end)

      assert {:ok, result} = UploadMedia.handler(
        %{"media_data" => video_data, "media_type" => "video/mp4"},
        %{}
      )

      assert result.requires_processing == true
      assert result.processing_state == "pending"
    end

    test "returns error when INIT fails with 403" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "errors" => [%{"message" => "Unauthorized", "code" => 135}]
        }))
      end)

      assert {:error, message} = UploadMedia.handler(
        %{"media_data" => @small_image, "media_type" => "image/jpeg"},
        %{}
      )
      assert message =~ "Upload INIT failed"
    end

    test "returns error when media_type is missing" do
      assert {:error, _} = UploadMedia.handler(%{"media_data" => @small_image}, %{})
    end

    test "returns error when media_data is missing" do
      assert {:error, _} = UploadMedia.handler(%{"media_type" => "image/jpeg"}, %{})
    end
  end
end