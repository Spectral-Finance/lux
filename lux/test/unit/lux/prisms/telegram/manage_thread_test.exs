defmodule Lux.Prisms.Telegram.ManageThreadTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Telegram.ManageThread
  alias Lux.Integrations.Telegram.ThreadManager

  setup do
    {:ok, pid} = ThreadManager.start_link()
    {:ok, manager: pid}
  end

  test "adds and retrieves a message via prism", %{manager: manager} do
    msg = %{"message_id" => 1, "text" => "hello"}
    
    assert {:ok, _} = ManageThread.run(%{
      "action" => "add_message",
      "pid" => manager,
      "chat_id" => "123",
      "message" => msg
    })

    assert {:ok, %{"thread" => thread}} = ManageThread.run(%{
      "action" => "get_thread",
      "pid" => manager,
      "chat_id" => "123",
      "message_id" => 1
    })

    assert length(thread) == 1
    assert Enum.at(thread, 0)["text"] == "hello"
  end

  test "adds and retrieves a callback query via prism", %{manager: manager} do
    cb = %{"id" => "q1", "data" => "click"}

    assert {:ok, _} = ManageThread.run(%{
      "action" => "add_callback",
      "pid" => manager,
      "callback_query" => cb
    })

    assert {:ok, %{"callbacks" => [^cb]}} = ManageThread.run(%{
      "action" => "get_callbacks",
      "pid" => manager
    })
  end

  test "prunes thread manager via prism", %{manager: manager} do
    assert {:ok, _} = ManageThread.run(%{
      "action" => "prune",
      "pid" => manager
    })
  end
end
