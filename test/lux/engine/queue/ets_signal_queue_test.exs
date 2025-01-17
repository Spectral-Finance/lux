defmodule Lux.Engine.Queue.ETSSignalQueueTest do
  # Not async due to ETS table name conflicts
  use ExUnit.Case, async: false

  alias Lux.Engine.Queue.ETSSignalQueue

  setup do
    table_name = :"test_queue_#{:erlang.unique_integer()}"
    {:ok, table} = ETSSignalQueue.init(table_name: table_name)

    on_exit(fn ->
      ETSSignalQueue.cleanup(table)
    end)

    %{table: table}
  end

  describe "init/1" do
    test "creates a new ETS table with correct options" do
      table_name = :"test_queue_#{:erlang.unique_integer()}"
      {:ok, table} = ETSSignalQueue.init(table_name: table_name)

      info = :ets.info(table)
      assert info[:type] == :ordered_set
      assert info[:named_table] == true
      assert info[:read_concurrency] == true
      assert info[:write_concurrency] == true
      assert info[:protection] == :public

      ETSSignalQueue.cleanup(table)
    end

    test "recreates table if it already exists" do
      table_name = :"test_queue_#{:erlang.unique_integer()}"
      {:ok, table1} = ETSSignalQueue.init(table_name: table_name)
      {:ok, table2} = ETSSignalQueue.init(table_name: table_name)

      assert table1 == table2
      assert :ets.info(table1) != :undefined

      ETSSignalQueue.cleanup(table1)
    end
  end

  describe "push/2" do
    test "adds signal to queue", %{table: table} do
      signal = %{type: "test.event"}
      assert :ok = ETSSignalQueue.push(table, signal)
      assert ETSSignalQueue.length(table) == 1
    end

    test "maintains FIFO order", %{table: table} do
      signals = [
        %{id: 1},
        %{id: 2},
        %{id: 3}
      ]

      Enum.each(signals, &ETSSignalQueue.push(table, &1))

      assert {:ok, %{id: 1}} = ETSSignalQueue.pop(table)
      assert {:ok, %{id: 2}} = ETSSignalQueue.pop(table)
      assert {:ok, %{id: 3}} = ETSSignalQueue.pop(table)
    end
  end

  describe "pop/1" do
    test "returns empty when queue is empty", %{table: table} do
      assert {:empty, nil} = ETSSignalQueue.pop(table)
    end

    test "removes and returns first signal", %{table: table} do
      signal = %{type: "test.event"}
      :ok = ETSSignalQueue.push(table, signal)

      assert {:ok, ^signal} = ETSSignalQueue.pop(table)
      assert ETSSignalQueue.length(table) == 0
    end
  end

  describe "length/1" do
    test "returns correct queue length", %{table: table} do
      assert ETSSignalQueue.length(table) == 0

      ETSSignalQueue.push(table, %{id: 1})
      assert ETSSignalQueue.length(table) == 1

      ETSSignalQueue.push(table, %{id: 2})
      assert ETSSignalQueue.length(table) == 2

      ETSSignalQueue.pop(table)
      assert ETSSignalQueue.length(table) == 1
    end
  end

  describe "cleanup/1" do
    test "removes the ETS table", %{table: table} do
      assert :ok = ETSSignalQueue.cleanup(table)
      assert :ets.info(table) == :undefined
    end

    test "succeeds when table doesn't exist" do
      assert :ok = ETSSignalQueue.cleanup(:nonexistent_table)
    end
  end
end
