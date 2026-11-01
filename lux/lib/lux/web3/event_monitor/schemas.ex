defmodule Lux.Web3.EventMonitor.Schemas do
  @moduledoc """
  Core domain schemas and structs for the Smart Contract Event Monitoring System (#75).

  Defines strongly typed data models for subscriptions, events, filter patterns,
  and webhook deliveries across multi-chain EVM networks.
  """

  defmodule Subscription do
    @moduledoc """
    Represents an active or paused contract event subscription.
    """
    @enforce_keys [:id, :chain_id, :chain, :contract_address]
    defstruct [
      :id,
      :name,
      :chain_id,
      :chain,
      :contract_address,
      :event_name,
      :event_signature,
      :topic0,
      topics: [],
      filter_pattern: %{},
      webhook_url: nil,
      webhook_secret: nil,
      status: :active,
      start_block: nil,
      last_processed_block: nil,
      created_at: 0,
      updated_at: 0
    ]

    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t() | nil,
            chain_id: non_neg_integer(),
            chain: atom(),
            contract_address: String.t(),
            event_name: String.t() | nil,
            event_signature: String.t() | nil,
            topic0: String.t() | nil,
            topics: [String.t() | nil],
            filter_pattern: map(),
            webhook_url: String.t() | nil,
            webhook_secret: String.t() | nil,
            status: :active | :paused | :stopped,
            start_block: non_neg_integer() | nil,
            last_processed_block: non_neg_integer() | nil,
            created_at: non_neg_integer(),
            updated_at: non_neg_integer()
          }
  end

  defmodule MonitoredEvent do
    @moduledoc """
    Represents a captured, parsed, and normalized smart contract event.
    """
    @enforce_keys [:id, :subscription_id, :chain_id, :chain, :contract_address, :tx_hash, :block_number]
    defstruct [
      :id,
      :subscription_id,
      :chain_id,
      :chain,
      :contract_address,
      :event_name,
      :event_signature,
      :block_number,
      :block_hash,
      :tx_hash,
      :log_index,
      topics: [],
      data: nil,
      decoded_params: %{},
      timestamp: 0
    ]

    @type t :: %__MODULE__{
            id: String.t(),
            subscription_id: String.t(),
            chain_id: non_neg_integer(),
            chain: atom(),
            contract_address: String.t(),
            event_name: String.t() | nil,
            event_signature: String.t() | nil,
            block_number: non_neg_integer(),
            block_hash: String.t() | nil,
            tx_hash: String.t(),
            log_index: non_neg_integer() | nil,
            topics: [String.t()],
            data: String.t() | nil,
            decoded_params: map(),
            timestamp: non_neg_integer()
          }
  end

  defmodule WebhookDelivery do
    @moduledoc """
    Represents the execution and delivery status of a webhook notification.
    """
    @enforce_keys [:id, :subscription_id, :event_id, :webhook_url]
    defstruct [
      :id,
      :subscription_id,
      :event_id,
      :webhook_url,
      status: :pending,
      attempts: 0,
      response_code: nil,
      error_message: nil,
      delivered_at: nil,
      created_at: 0
    ]

    @type t :: %__MODULE__{
            id: String.t(),
            subscription_id: String.t(),
            event_id: String.t(),
            webhook_url: String.t(),
            status: :pending | :delivered | :failed,
            attempts: non_neg_integer(),
            response_code: non_neg_integer() | nil,
            error_message: String.t() | nil,
            delivered_at: non_neg_integer() | nil,
            created_at: non_neg_integer()
          }
  end

  defmodule FilterPattern do
    @moduledoc """
    Structured filter criteria and value thresholds for pattern matching.
    """
    defstruct [
      min_value: nil,
      max_value: nil,
      from_whitelist: nil,
      to_whitelist: nil,
      address_blacklist: [],
      parameter_conditions: %{}
    ]

    @type t :: %__MODULE__{
            min_value: non_neg_integer() | nil,
            max_value: non_neg_integer() | nil,
            from_whitelist: [String.t()] | nil,
            to_whitelist: [String.t()] | nil,
            address_blacklist: [String.t()],
            parameter_conditions: map()
          }
  end

  @doc """
  Generates a deterministic composite event ID from chain_id, tx_hash, and log_index.
  """
  @spec generate_event_id(non_neg_integer(), String.t(), non_neg_integer() | nil) :: String.t()
  def generate_event_id(chain_id, tx_hash, log_index) do
    clean_tx = String.downcase(String.trim_leading(to_string(tx_hash), "0x"))
    l_idx = log_index || 0
    "evt_#{chain_id}_#{clean_tx}_#{l_idx}"
  end

  @doc """
  Normalizes an Ethereum/EVM hex address to lowercase with leading 0x.
  """
  @spec normalize_address(String.t() | nil) :: String.t() | nil
  def normalize_address(nil), do: nil
  def normalize_address(addr) when is_binary(addr) do
    clean = String.downcase(String.trim_leading(String.trim(addr), "0x"))
    if String.length(clean) == 40 do
      "0x" <> clean
    else
      String.downcase(addr)
    end
  end
  def normalize_address(_), do: nil
end
