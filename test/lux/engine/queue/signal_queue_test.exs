defmodule Lux.Engine.Queue.SignalQueueTest do
  use ExUnit.Case, async: true

  alias Lux.Engine.Queue.SignalQueue

  # Test implementation of the SignalQueue behaviour
  defmodule TestQueue do
    @behaviour SignalQueue

    def init(_opts), do: {:ok, []}
    def push(queue, signal), do: {:ok, [signal | queue]}
    def pop([]), do: {:empty, nil}
    def pop([signal | rest]), do: {:ok, signal, rest}
    def length(queue), do: Kernel.length(queue)
    def cleanup(_queue), do: :ok
  end

  describe "behaviour" do
    test "defines required callbacks" do
      callbacks = SignalQueue.behaviour_info(:callbacks)

      assert {:init, 1} in callbacks
      assert {:push, 2} in callbacks
      assert {:pop, 1} in callbacks
      assert {:length, 1} in callbacks
      assert {:cleanup, 1} in callbacks
    end

    test "validates callback implementations" do
      # This test will fail at compile time if TestQueue doesn't implement
      # all required callbacks with the correct arity
      assert function_exported?(TestQueue, :init, 1)
      assert function_exported?(TestQueue, :push, 2)
      assert function_exported?(TestQueue, :pop, 1)
      assert function_exported?(TestQueue, :length, 1)
      assert function_exported?(TestQueue, :cleanup, 1)
    end
  end
end
