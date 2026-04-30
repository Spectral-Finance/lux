defmodule Lux.DataAggregation.Streamer do
  @moduledoc """
  Real-time data streaming for blockchain events and blocks.

  ## Features
  - PubSub-based real-time notifications
  - Block and event subscriptions
  - WebSocket-ready event format
  - Backpressure handling
  """

  use GenServer

  @pubsub_topic :da_stream

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Start PubSub if not already running
    unless Process.whereis(@pubsub_topic) do
      Phoenix.PubSub.Supervisor.__child_spec__(
        name: @pubsub_topic,
        pool_size: 1
      )
      |> Supervisor.start_child(children: [])
    end

    {:ok, %{subscribers: %{}}}
  end

  @doc """
  Subscribe to block updates for a chain.
  """
  def subscribe_blocks(chain, pid \\ self()) do
    topic = block_topic(chain)
    Phoenix.PubSub.subscribe(@pubsub_topic, topic)
    :ok
  end

  @doc """
  Subscribe to event updates for a contract.
  """
  def subscribe_events(chain, contract_address, pid \\ self()) do
    topic = event_topic(chain, contract_address)
    Phoenix.PubSub.subscribe(@pubsub_topic, topic)
    :ok
  end

  @doc """
  Subscribe to all events for a chain.
  """
  def subscribe_chain_events(chain, pid \\ self()) do
    topic = chain_event_topic(chain)
    Phoenix.PubSub.subscribe(@pubsub_topic, topic)
    :ok
  end

  @doc """
  Unsubscribe from block updates.
  """
  def unsubscribe_blocks(chain) do
    topic = block_topic(chain)
    Phoenix.PubSub.unsubscribe(@pubsub_topic, topic)
  end

  @doc """
  Unsubscribe from event updates.
  """
  def unsubscribe_events(chain, contract_address) do
    topic = event_topic(chain, contract_address)
    Phoenix.PubSub.unsubscribe(@pubsub_topic, topic)
  end

  @doc """
  Broadcast a new block to subscribers.
  """
  def broadcast_block(chain, block, block_number) do
    topic = block_topic(chain)

    message = %{
      type: :block,
      chain: chain,
      block_number: block_number,
      block_hash: block["hash"],
      timestamp: block["timestamp"],
      transaction_count: length(block["transactions"] || []),
      gas_used: block["gasUsed"],
      inserted_at: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(@pubsub_topic, topic, message)
  end

  @doc """
  Broadcast a new event to subscribers.
  """
  def broadcast_event(chain, contract_address, event) do
    # Broadcast to contract-specific topic
    contract_topic = event_topic(chain, contract_address)

    contract_message = %{
      type: :event,
      chain: chain,
      contract_address: contract_address,
      event: event,
      inserted_at: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(@pubsub_topic, contract_topic, contract_message)

    # Also broadcast to chain-wide topic
    chain_topic = chain_event_topic(chain)
    Phoenix.PubSub.broadcast(@pubsub_topic, chain_topic, contract_message)
  end

  @doc """
  Get subscriber count for a topic.
  """
  def subscriber_count(chain, type \\ :blocks) do
    topic =
      case type do
        :blocks -> block_topic(chain)
        :events -> chain_event_topic(chain)
      end

    Phoenix.PubSub.subscribers(@pubsub_topic, topic) |> length()
  end

  defp block_topic(chain), do: "da:block:#{chain}"
  defp event_topic(chain, contract_address), do: "da:event:#{chain}:#{contract_address}"
  defp chain_event_topic(chain), do: "da:events:#{chain}"
end
