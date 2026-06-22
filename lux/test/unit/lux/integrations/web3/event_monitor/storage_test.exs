defmodule Lux.Integrations.Web3.EventMonitor.StorageTest do
  use ExUnit.Case, async: false
  alias Lux.Integrations.Web3.EventMonitor.Storage

  setup do
    case Storage.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
    Storage.clear()
    :ok
  end

  test "inserts and queries events" do
    event = %{"address" => "0x123", "topics" => ["0xABC"], "data" => "0x..."}
    Storage.insert(event)

    assert [^event] = Storage.query()
  end

  test "filters by address" do
    Storage.insert(%{"address" => "0x123", "data" => "1"})
    Storage.insert(%{"address" => "0x456", "data" => "2"})

    assert [%{"data" => "1"}] = Storage.query(address: "0x123")
    assert [%{"data" => "2"}] = Storage.query(address: "0x456")
  end

  test "filters by topic" do
    Storage.insert(%{"topics" => ["0xAAA"], "data" => "1"})
    Storage.insert(%{"topics" => ["0xBBB"], "data" => "2"})

    assert [%{"data" => "1"}] = Storage.query(topic: "0xAAA")
  end

  test "clears events" do
    Storage.insert(%{"address" => "0x123"})
    Storage.clear()
    assert [] = Storage.query()
  end
end
