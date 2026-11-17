defmodule Lux.Prisms.DiscordTest do
  use ExUnit.Case
  alias Lux.Prisms.Discord.MessageManagement
  alias Lux.Prisms.Discord.Moderation

  describe "MessageManagementPrism" do
    test "successfully formats message data through lens" do
      raw_msg = %{
        id: "123",
        content: "Hello Lux",
        author: %{id: "456"},
        channel_id: "789",
        timestamp: "2023-10-01T12:00:00Z",
        mentions: []
      }
      
      view = Lux.Lenses.Discord.Message.view(raw_msg)
      assert view.id == "123"
      assert view.content == "Hello Lux"
    end
  end

  describe "ModerationPrism" do
    test "handles warning persistence" do
      params = %{action: :warn, guild_id: "g1", user_id: "u1", reason: "Spam"}
      assert {:ok, %{status: "warning_recorded"}} = Moderation.run(params)
    end
  end
end
