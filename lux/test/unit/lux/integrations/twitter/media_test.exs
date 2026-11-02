defmodule Lux.Integrations.Twitter.MediaTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Twitter.Media

  describe "upload_simple/3" do
    test "uploads small image and returns media_id" do
      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "media_id" => 123456789,
            "media_id_string" => "123456789",
            "size" => 1024
          })
        )
      end

      binary_payload = :crypto.strong_rand_bytes(1024)

      {:ok, result} =
        Media.upload_simple(binary_payload, "image/jpeg", %{plug: plug})

      assert result.media_id == "123456789"
      assert result.size == 1024
      assert result.media_type == "image/jpeg"
    end
  end

  describe "chunked upload pipeline" do
    test "executes INIT, APPEND, and FINALIZE steps" do
      init_plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"media_id_string" => "chunked_media_999"}))
      end

      {:ok, media_id} =
        Media.chunked_init(5_000_000, "video/mp4", "tweet_video", %{plug: init_plug})

      assert media_id == "chunked_media_999"

      append_plug = fn conn ->
        conn
        |> Plug.Conn.resp(204, "")
      end

      chunk = :crypto.strong_rand_bytes(1_000_000)
      assert :ok = Media.chunked_append(media_id, 0, chunk, %{plug: append_plug})

      finalize_plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"media_id_string" => "chunked_media_999", "state" => "succeeded"}))
      end

      assert {:ok, %{"state" => "succeeded"}} =
               Media.chunked_finalize(media_id, %{plug: finalize_plug})
    end
  end
end
