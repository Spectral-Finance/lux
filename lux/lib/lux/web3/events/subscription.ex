defmodule Lux.Web3.Events.Subscription do
  @moduledoc """
  Represents a subscription to contract events.

  A subscription tracks which contracts and event signatures (topics)
  to monitor, along with configuration for polling intervals, block
  ranges, and webhook destinations.
  """

  use Lux.Types

  defstruct id: nil,
            chain_id: 1,
            contract_address: "",
            event_signatures: [],
            poll_interval_ms: 5_000,
            from_block: 0,
            to_block: :latest,
            enabled: true,
            webhook_url: nil,
            created_at: nil,
            updated_at: nil,
            last_synced_block: 0,
            metadata: %{}

  @type t :: %__MODULE__{
          id: String.t() | nil,
          chain_id: pos_integer(),
          contract_address: String.t(),
          event_signatures: [String.t()],
          poll_interval_ms: pos_integer(),
          from_block: non_neg_integer(),
          to_block: :latest | non_neg_integer(),
          enabled: boolean(),
          webhook_url: String.t() | nil,
          created_at: String.t() | nil,
          updated_at: String.t() | nil,
          last_synced_block: non_neg_integer(),
          metadata: map()
        }

  @doc """
  Creates a new subscription.
  """
  @spec new(attrs :: map()) :: t()
  def new(attrs \ %{}) do
    attrs = Map.put_new(attrs, :id, Lux.UUID.generate())
    attrs = Map.put_new(attrs, :poll_interval_ms, 5_000)
    attrs = Map.put_new(attrs, :enabled, true)
    attrs = Map.put_new(attrs, :last_synced_block, 0)

    struct!(__MODULE__, attrs)
  end

  @doc """
  Creates a subscription from an event signature string.
  Example: "Transfer(address,address,uint256)"
  """
  @spec from_signature(chain_id :: pos_integer(), contract :: String.t(), signature :: String.t()) :: t()
  def from_signature(chain_id, contract, signature) do
    topic0 = Lux.Web3.Events.Decoder.event_signature_to_topic(signature)

    new(%{
              chain_id: chain_id,
              contract_address: contract,
              event_signatures: [signature],
              topic0: topic0
            })
  end

  @doc """
  Checks if a given topic0 matches any of the subscription's event signatures.
  """
  @spec topic_matches?(t(), String.t()) :: boolean()
  def topic_matches?(subscription, topic0) when is_binary(topic0) and topic0 != "" do
    Enum.any?(subscription.event_signatures, fn sig ->
      expected_topic = Lux.Web3.Events.Decoder.event_signature_to_topic(sig)
      topic0 == expected_topic
    end)
  end

  def topic_matches?(_subscription, _topic0), do: false

  @doc """
  Returns the effective block range for polling.
  """
  @spec block_range(t()) :: {non_neg_integer(), :latest | non_neg_integer()}
  def block_range(subscription) do
    {subscription.last_synced_block + 1, subscription.to_block}
  end

  @doc """
  Updates the last synced block.
  """
  @spec mark_synced(t(), non_neg_integer()) :: t()
  def mark_synced(subscription, block_number) do
    %{subscription | last_synced_block: max(subscription.last_synced_block, block_number)}
  end
end
