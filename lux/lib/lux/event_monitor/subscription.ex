defmodule Lux.EventMonitor.Subscription do
  @moduledoc """
  Represents an event monitoring subscription.

  A subscription defines which events to watch for on which contract and chain,
  including optional ABI for decoding, filters for matching, and configuration
  for polling behavior.

  ## Fields

    * `id` - Unique subscription identifier
    * `address` - Contract address to monitor
    * `chain_id` - Chain identifier (1 = Ethereum mainnet, 137 = Polygon, etc.)
    * `abi` - Contract ABI for event decoding (optional)
    * `event_names` - List of event names to monitor (empty = all events)
    * `topics` - Topic filters for raw filtering (optional)
    * `filter` - Additional filter specification (optional)
    * `from_block` - Block to start monitoring from
    * `last_synced_block` - Last block that was fully processed
    * `poll_interval_ms` - Polling interval in milliseconds
    * `active` - Whether the subscription is active
    * `created_at` - Creation timestamp
    * `metadata` - Arbitrary metadata
  """

  @type t :: %__MODULE__{
          id: String.t(),
          address: String.t(),
          chain_id: pos_integer(),
          abi: [map()] | nil,
          event_names: [String.t()],
          topics: [String.t() | nil] | nil,
          filter: map() | nil,
          from_block: non_neg_integer() | :latest,
          last_synced_block: non_neg_integer() | nil,
          poll_interval_ms: pos_integer(),
          active: boolean(),
          created_at: non_neg_integer(),
          metadata: map()
        }

  defstruct [
    :id,
    :address,
    :chain_id,
    :abi,
    :topics,
    :filter,
    :from_block,
    :last_synced_block,
    :created_at,
    event_names: [],
    poll_interval_ms: 15_000,
    active: true,
    metadata: %{}
  ]

  @doc """
  Creates a new subscription with a generated ID.

  ## Parameters

    * `attrs` - Subscription attributes

  ## Required Attributes

    * `:address` - Contract address to monitor
    * `:chain_id` - Chain identifier

  ## Examples

      iex> Lux.EventMonitor.Subscription.new(%{
      ...>   address: "0xdead...",
      ...>   chain_id: 1,
      ...>   event_names: ["Transfer", "Approval"]
      ...> })
      %Lux.EventMonitor.Subscription{id: "sub_...", address: "0xdead...", ...}
  """
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      id: Map.get(attrs, :id, generate_id()),
      address: Map.fetch!(attrs, :address),
      chain_id: Map.fetch!(attrs, :chain_id),
      abi: Map.get(attrs, :abi),
      event_names: Map.get(attrs, :event_names, []),
      topics: Map.get(attrs, :topics),
      filter: Map.get(attrs, :filter),
      from_block: Map.get(attrs, :from_block, :latest),
      last_synced_block: Map.get(attrs, :last_synced_block),
      poll_interval_ms: Map.get(attrs, :poll_interval_ms, 15_000),
      active: Map.get(attrs, :active, true),
      created_at: System.system_time(:second),
      metadata: Map.get(attrs, :metadata, %{})
    }
  end

  @doc """
  Updates the last synced block for a subscription.
  """
  @spec update_last_synced(t(), non_neg_integer()) :: t()
  def update_last_synced(%__MODULE__{} = sub, block_number) do
    %{sub | last_synced_block: block_number}
  end

  @doc """
  Activates the subscription.
  """
  @spec activate(t()) :: t()
  def activate(%__MODULE__{} = sub), do: %{sub | active: true}

  @doc """
  Deactivates the subscription.
  """
  @spec deactivate(t()) :: t()
  def deactivate(%__MODULE__{} = sub), do: %{sub | active: false}

  @doc """
  Returns the block number to start the next poll from.
  """
  @spec next_poll_from(t()) :: non_neg_integer() | :latest
  def next_poll_from(%__MODULE__{last_synced_block: nil, from_block: from}), do: from
  def next_poll_from(%__MODULE__{last_synced_block: block}), do: block + 1

  defp generate_id do
    "sub_" <> (System.unique_integer([:positive]) |> Integer.to_string(36) |> String.downcase())
  end
end
