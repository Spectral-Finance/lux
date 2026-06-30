defmodule Lux.Integrations.Telegram.ThreadManager do
  @moduledoc """
  A stateful GenServer to manage conversation threads, reply hierarchies,
  and callback queries from Telegram Bot API updates.

  ## Lifecycle Notes
  Currently, this is an unbounded in-memory cache. For production use with
  high traffic, consider implementing a pruning strategy (e.g., TTL, max limits),
  or use an external store like Redis.
  A basic `prune/1` function is provided to clear all state manually.
  Traversal depth is limited to prevent infinite cycles or overly large threads.
  """

  use GenServer
  require Logger

  @max_depth 50

  # State:
  # - messages: Map of %{ {chat_id, message_id} => message_map }
  # - replies: Map of %{ {chat_id, message_id} => parent_message_id }
  # - callbacks: List of received callback queries
  defstruct messages: %{}, replies: %{}, callbacks: []

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Registers an incoming message. Resolves reply-to hierarchies.
  """
  def add_message(pid, chat_id, message) do
    GenServer.call(pid, {:add_message, chat_id, message})
  end

  @doc """
  Gets the entire thread chain (from parent/root to latest reply) for a message.
  """
  def get_thread(pid, chat_id, message_id) do
    GenServer.call(pid, {:get_thread, chat_id, message_id})
  end

  @doc """
  Registers an incoming callback query.
  """
  def add_callback(pid, callback_query) do
    GenServer.call(pid, {:add_callback, callback_query})
  end

  @doc """
  Lists all received callback queries.
  """
  def get_callbacks(pid) do
    GenServer.call(pid, :get_callbacks)
  end

  @doc """
  Manually prunes/clears all stored messages and callbacks to manage memory.
  """
  def prune(pid) do
    GenServer.call(pid, :prune)
  end

  # Server Callbacks

  @impl true
  def init(:ok) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call({:add_message, chat_id, message}, _from, state) do
    msg_id = message["message_id"]
    reply_to = message["reply_to_message"] || %{}
    parent_id = reply_to["message_id"]

    new_messages = Map.put(state.messages, {chat_id, msg_id}, message)

    new_replies = 
      if is_nil(parent_id) do
        state.replies
      else
        Map.put(state.replies, {chat_id, msg_id}, parent_id)
      end

    new_state = %{state | messages: new_messages, replies: new_replies}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:get_thread, chat_id, message_id}, _from, state) do
    # 1. Resolve to root message by traversing up
    root_id = find_root(chat_id, message_id, state.replies)

    # 2. Collect all descendant replies (simple search in replies map)
    thread_ids = collect_thread_ids(chat_id, root_id, state.replies, [root_id])

    # 3. Fetch full message maps
    thread_messages = 
      thread_ids
      |> Enum.sort()
      |> Enum.map(fn id -> Map.get(state.messages, {chat_id, id}) end)
      |> Enum.reject(&is_nil/1)

    {:reply, thread_messages, state}
  end

  @impl true
  def handle_call({:add_callback, callback_query}, _from, state) do
    case callback_query do
      %{"id" => _, "data" => _} ->
        new_callbacks = [callback_query | state.callbacks]
        {:reply, :ok, %{state | callbacks: new_callbacks}}
      _ ->
        {:reply, {:error, :invalid_payload}, state}
    end
  end

  @impl true
  def handle_call(:get_callbacks, _from, state) do
    {:reply, state.callbacks, state}
  end

  @impl true
  def handle_call(:prune, _from, _state) do
    {:reply, :ok, %__MODULE__{}}
  end

  # Helper to traverse up the reply hierarchy to find the root message
  defp find_root(chat_id, message_id, replies, depth \\ 0)
  defp find_root(_chat_id, message_id, _replies, depth) when depth >= @max_depth, do: message_id
  defp find_root(chat_id, message_id, replies, depth) do
    case Map.get(replies, {chat_id, message_id}) do
      nil -> message_id
      parent_id -> find_root(chat_id, parent_id, replies, depth + 1)
    end
  end

  # Helper to collect all child message IDs in a thread
  defp collect_thread_ids(chat_id, parent_id, replies, acc, depth \\ 0)
  defp collect_thread_ids(_chat_id, _parent_id, _replies, acc, depth) when depth >= @max_depth, do: acc
  defp collect_thread_ids(chat_id, parent_id, replies, acc, depth) do
    children = 
      replies
      |> Enum.filter(fn {{c_id, _m_id}, p_id} -> c_id == chat_id and p_id == parent_id end)
      |> Enum.map(fn {{_, m_id}, _} -> m_id end)

    case children do
      [] -> acc
      list -> 
        Enum.reduce(list, acc ++ list, fn child_id, cur_acc ->
          collect_thread_ids(chat_id, child_id, replies, cur_acc, depth + 1)
        end)
    end
  end
end
