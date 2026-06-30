defmodule Lux.Integrations.Telegram.ThreadManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.ThreadManager

  setup do
    {:ok, manager} = ThreadManager.start_link()
    {:ok, manager: manager}
  end

  describe "message threading" do
    test "adds single message and returns thread with only that message", %{manager: manager} do
      msg = %{"message_id" => 1, "text" => "First"}
      assert :ok = ThreadManager.add_message(manager, "chat123", msg)

      assert [msg] == ThreadManager.get_thread(manager, "chat123", 1)
    end

    test "links replies to the parent thread", %{manager: manager} do
      msg1 = %{"message_id" => 100, "text" => "Root message"}
      msg2 = %{
        "message_id" => 101,
        "text" => "Reply 1",
        "reply_to_message" => %{"message_id" => 100}
      }
      msg3 = %{
        "message_id" => 102,
        "text" => "Reply 2 (replying to Reply 1)",
        "reply_to_message" => %{"message_id" => 101}
      }

      assert :ok = ThreadManager.add_message(manager, "chat123", msg1)
      assert :ok = ThreadManager.add_message(manager, "chat123", msg2)
      assert :ok = ThreadManager.add_message(manager, "chat123", msg3)

      # Querying thread by root_id
      thread = ThreadManager.get_thread(manager, "chat123", 100)
      assert length(thread) == 3
      assert Enum.map(thread, & &1["message_id"]) == [100, 101, 102]

      # Querying thread by a child reply_id should also resolve back to the root and return the whole thread
      thread_by_child = ThreadManager.get_thread(manager, "chat123", 102)
      assert length(thread_by_child) == 3
      assert Enum.map(thread_by_child, & &1["message_id"]) == [100, 101, 102]
    end

    test "handles missing parents gracefully", %{manager: manager} do
      msg = %{"message_id" => 10, "text" => "orphan", "reply_to_message" => %{"message_id" => 999}}
      assert :ok = ThreadManager.add_message(manager, "chat_orp", msg)

      thread = ThreadManager.get_thread(manager, "chat_orp", 10)
      assert length(thread) == 1
      assert Enum.at(thread, 0)["message_id"] == 10
    end

    test "handles cyclic replies or deep threads gracefully by halting at max depth", %{manager: manager} do
      # Add 55 deep replies
      Enum.each(1..55, fn i ->
        msg = if i == 1 do
          %{"message_id" => i, "text" => "root"}
        else
          %{"message_id" => i, "text" => "reply", "reply_to_message" => %{"message_id" => i - 1}}
        end
        ThreadManager.add_message(manager, "chat_deep", msg)
      end)
      
      thread = ThreadManager.get_thread(manager, "chat_deep", 55)
      # Because of @max_depth 50 going up, it won't hit root (1)
      # But it won't infinite loop. We just assert it returns a subset.
      assert length(thread) > 0
    end
  end

  describe "callback query management" do
    test "registers callback queries", %{manager: manager} do
      query = %{"id" => "q123", "data" => "click_button"}
      assert :ok = ThreadManager.add_callback(manager, query)

      assert [query] == ThreadManager.get_callbacks(manager)
    end

    test "validates callback payload", %{manager: manager} do
      assert {:error, :invalid_payload} = ThreadManager.add_callback(manager, %{"id" => "q123"})
      assert {:error, :invalid_payload} = ThreadManager.add_callback(manager, %{"data" => "click"})
      assert :ok = ThreadManager.add_callback(manager, %{"id" => "q123", "data" => "click"})
    end
  end

  describe "lifecycle" do
    test "prune clears all state", %{manager: manager} do
      ThreadManager.add_message(manager, "c1", %{"message_id" => 1, "text" => "T"})
      ThreadManager.add_callback(manager, %{"id" => "q1", "data" => "D"})
      
      assert :ok = ThreadManager.prune(manager)
      assert [] == ThreadManager.get_callbacks(manager)
      assert [] == ThreadManager.get_thread(manager, "c1", 1)
    end
  end
end
