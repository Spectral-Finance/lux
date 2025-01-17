defmodule Lux.Engine.Queue.SignalQueue do
  @moduledoc """
  Behaviour defining the contract for signal queue implementations.
  A signal queue is responsible for storing and retrieving signals in a FIFO manner.
  """

  @type signal :: map()
  @type queue_ref :: any()
  @type error :: {:error, term()}

  @doc """
  Initializes a new signal queue.
  Returns a reference that can be used in other operations.
  """
  @callback init(opts :: keyword()) :: {:ok, queue_ref()} | error()

  @doc """
  Pushes a new signal to the queue.
  """
  @callback push(queue_ref(), signal()) :: :ok | error()

  @doc """
  Pops the next signal from the queue.
  Returns nil if queue is empty.
  """
  @callback pop(queue_ref()) :: {:ok, signal()} | {:empty, nil} | error()

  @doc """
  Returns the current length of the queue.
  """
  @callback length(queue_ref()) :: non_neg_integer()

  @doc """
  Cleans up any resources used by the queue.
  """
  @callback cleanup(queue_ref()) :: :ok | error()
end
