defmodule Lux.YouTube.LiveStreaming.ChatManagerTest do
  use UnitCase, async: true

  alias Lux.YouTube.LiveStreaming.ChatManager

  describe "process_chat_batch/1 and generate_chat_response/1" do
    test "processes chat messages and extracts Super Chat donations" do
      items = [
        %{author: "Alice", text: "Great stream!", super_chat_usd: 0.0},
        %{author: "Bob", text: "Super cool demo!", super_chat_usd: 25.0},
        %{author: "Charlie", text: "Where is the repo?", super_chat_usd: 0.0}
      ]

      result = ChatManager.process_chat_batch(items)

      assert length(result.messages) == 3
      assert length(result.super_chats) == 1

      sc = List.first(result.super_chats)
      assert sc.author_name == "Bob"
      assert sc.super_chat_amount_usd == 25.0

      # Test response generation
      sc_reply = ChatManager.generate_chat_response(sc)
      assert String.contains?(sc_reply, "Bob")
      assert String.contains?(sc_reply, "$25.0")

      repo_msg = Enum.at(result.messages, 2)
      repo_reply = ChatManager.generate_chat_response(repo_msg)
      assert String.contains?(repo_reply, "github.com/Spectral-Finance/lux")
    end
  end
end
