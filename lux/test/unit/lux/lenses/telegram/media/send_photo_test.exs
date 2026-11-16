defmodule Lux.Lenses.Telegram.Media.SendPhotoTest do
  @moduledoc """
  Unit tests for Lux.Lenses.Telegram.Media.SendPhoto.
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Media.SendPhoto

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully sends a photo" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path =~ "/sendPhoto"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "ok" => true,
            "result" => %{
              "message_id" => 101,
              "date" => 1_700_000_000,
              "chat" => %{"id" => 123_456_789},
              "caption" => "Test Photo Caption",
              "photo" => [
                %{"file_id" => "small_thumb_id", "width" => 90, "height" => 90},
                %{"file_id" => "high_res_photo_id", "width" => 1280, "height" => 720}
              ]
            }
          })
        )
      end)

      assert {:ok,
              %{
                message_id: 101,
                chat_id: 123_456_789,
                caption: "Test Photo Caption",
                photo_id: "high_res_photo_id",
                date: 1_700_000_000
              }} =
               SendPhoto.focus(
                 %{
                   "chat_id" => "123456789",
                   "photo" => "https://example.com/image.png",
                   "caption" => "Test Photo Caption"
                 },
                 %{}
               )
    end
  end

  describe "schema validation" do
    test "validates required parameters" do
      lens = SendPhoto.view()
      assert lens.schema.required == ["chat_id", "photo"]
      assert Map.has_key?(lens.schema.properties, :chat_id)
      assert Map.has_key?(lens.schema.properties, :photo)
      assert Map.has_key?(lens.schema.properties, :caption)
    end
  end
end
