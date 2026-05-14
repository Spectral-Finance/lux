defmodule Lux.Lenses.Discord.Messages.ListPinsTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Messages.ListPins

  @channel_id "123456789012345678"

  describe "after_focus/1" do
    test "transforms pinned Discord messages" do
      assert {:ok,
              [
                %{
                  id: "111111111111111111",
                  content: "Pinned context",
                  pinned: true,
                  timestamp: "2026-05-14T09:30:00.000000+00:00",
                  author: %{id: "222222222222222222", username: "agent"}
                }
              ]} =
               ListPins.after_focus([
                 %{
                   "id" => "111111111111111111",
                   "content" => "Pinned context",
                   "pinned" => true,
                   "timestamp" => "2026-05-14T09:30:00.000000+00:00",
                   "author" => %{"id" => "222222222222222222", "username" => "agent"}
                 }
               ])
    end

    test "passes Discord API errors through" do
      assert {:error, %{"message" => "Missing Access"}} =
               ListPins.after_focus(%{"message" => "Missing Access"})
    end
  end

  describe "schema validation" do
    test "validates schema" do
      lens = ListPins.view()
      assert lens.schema.required == ["channel_id"]
      assert Map.has_key?(lens.schema.properties, :channel_id)
      assert lens.url == "https://discord.com/api/v10/channels/:channel_id/pins"
      assert lens.method == :get
    end
  end
end
