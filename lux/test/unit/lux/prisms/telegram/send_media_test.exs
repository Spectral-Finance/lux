defmodule Lux.Prisms.Telegram.SendMediaTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Telegram.SendMedia

  setup do
    Req.Test.stub(Lux.Telegram.MediaMock, fn conn ->
      Req.Test.json(conn, %{
        "ok" => true,
        "result" => %{"message_id" => 1000, "photo" => [%{"file_id" => "abc"}]}
      })
    end)

    :ok
  end

  test "sends a photo by URL" do
    assert {:ok, result} =
             SendMedia.handler(
               %{
                 chat_id: 123,
                 media_type: "photo",
                 media: "https://example.com/photo.jpg",
                 caption: "Test photo",
                 token: "t",
                 plug: {Req.Test, Lux.Telegram.MediaMock}
               },
               []
             )

    assert result["message_id"] == 1000
  end

  test "sends a document" do
    assert {:ok, _} =
             SendMedia.handler(
               %{
                 chat_id: 123,
                 media_type: "document",
                 media: "BQACAgIAAxkBAAI...",
                 token: "t",
                 plug: {Req.Test, Lux.Telegram.MediaMock}
               },
               []
             )
  end
end
