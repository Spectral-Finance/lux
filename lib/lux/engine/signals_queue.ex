defmodule Lux.Engine.SignalsQueue do
  @moduledoc """
  Behaviour defining the contract for signal queue implementations.
  A signal queue is responsible for storing and retrieving signals in a FIFO manner.
  """

  @type_doc """
  Anything that can be used as a reference to the signal queue.
  """
  @type queue_ref :: any()
  @type error :: {:error, term()}

  @implementation Application.compile_env(:lux, :signals_queue_implementation)

  @doc """
  Initializes a new signal queue.
  Returns a reference that can be used in other operations.
  """
  @callback start_link(opts :: keyword()) :: {:ok, queue_ref()} | error()

  @doc """
  Returns a child spec for the signal queue.
  """
  @callback child_spec(opts :: keyword()) :: Supervisor.child_spec()

  @doc """
  Pushes a new signal to the queue.
  """
  @callback push(queue_ref(), Lux.Signal.t()) :: :ok | error()

  @doc """
  Pops the next signal from the queue.
  Returns nil if queue is empty.
  """
  @callback pop(queue_ref()) :: {:ok, Lux.Signal.t()} | {:empty, nil} | error()

  @doc """
  Returns the current length of the queue.
  """
  @callback length(queue_ref()) :: non_neg_integer()

  @doc """
  Cleans up any resources used by the queue.
  """
  @callback cleanup(queue_ref()) :: :ok | error()

  @doc """
  Returns a list of signals from the queue.
  """
  @callback to_list(queue_ref()) :: [Lux.Signal.t()] | error()

  def start_link(opts \\ []), do: @implementation.start_link(opts)
  def push(queue, signal), do: @implementation.push(queue, signal)
  def pop(queue), do: @implementation.pop(queue)
  def length(queue), do: @implementation.length(queue)
  def cleanup(queue), do: @implementation.cleanup(queue)
  def to_list(queue), do: @implementation.to_list(queue)
  def child_spec(opts \\ []), do: @implementation.child_spec(opts)
end
