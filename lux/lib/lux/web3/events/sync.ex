defmodule Lux.Web3.Events.Sync do
  @moduledoc """
  Historical event syncing and polling capabilities.

  Provides two modes of event retrieval:
  1. Historical backfill - scans large block ranges in chunks
  2. Live polling - checks for new events since last sync point
  """

  alias Lux.Lenses.Etherscan.GetLogs
  alias Lux.Web3.Events.Event
  alias Lux.Web3.Events.Subscription
  alias Lux.Web3.Events.Decoder

  @max_block_range 5000  # Max blocks per API call to avoid timeouts
  @max_page_offset 1000  # Etherscan max per page

  # Historical Sync

  @doc """
  Performs a historical sync for a subscription from its from_block
  up to the latest block or its to_block limit.
  """
  @spec historical_sync(Subscription.t()) :: {:ok, [Event.t()]} | {:error, term()}
  def historical_sync(%Subscription{from_block: from, to_block: :latest} = sub) do
    latest_block = get_latest_block(sub.chain_id)
    do_historical_sync(sub, from, latest_block)
  end

  def historical_sync(%Subscription{from_block: from, to_block: to} = sub)
      when is_integer(to) and to >= from do
    do_historical_sync(sub, from, to)
  end

  def historical_sync(_sub), do: {:error, :invalid_block_range}

  @doc """
  Polls for new events since the subscription's last synced block.
  """
  @spec poll_new_events(Subscription.t()) :: {:ok, [Event.t()]} | {:error, term()}
  def poll_new_events(%Subscription{last_synced_block: last, to_block: :latest} = sub) do
    latest_block = get_latest_block(sub.chain_id)

    if latest_block <= last do
      {:ok, []}
    else
      from_block = last + 1
      to_block = min(from_block + @max_block_range - 1, latest_block)
      fetch_and_decode_events(sub, from_block, to_block)
    end
  end

  def poll_new_events(sub) do
    {from, to} = Subscription.block_range(sub)

    if to <= from - 1 do
      {:ok, []}
    else
      to_actual = min(to, from + @max_block_range - 1)
      fetch_and_decode_events(sub, from, to_actual)
    end
  end

  # Internal helpers

  defp do_historical_sync(sub, from, to) do
    if to - from + 1 > @max_block_range * 10 do
      # Split into chunks for very large ranges
      chunks = div(to - from + 1, @max_block_range)
      Enum.reduce(0..chunks, [], fn i, acc ->
        chunk_from = from + i * @max_block_range
        chunk_to = min(chunk_from + @max_block_range - 1, to)

        case fetch_and_decode_events(sub, chunk_from, chunk_to) do
          {:ok, events} -> acc ++ events
          {:error, _} -> acc
        end
      end)
      |> then(&{:ok, &1})
    else
      fetch_and_decode_events(sub, from, to)
    end
  end

  @doc """
  Fetches and decodes events for a block range using the Etherscan GetLogs lens.
  """
  @spec fetch_and_decode_events(Subscription.t(), non_neg_integer(), non_neg_integer()) ::
          {:ok, [Event.t()]} | {:error, term()}
  def fetch_and_decode_events(sub, from_block, to_block) do
    params = %{
      chainid: sub.chain_id,
      address: sub.contract_address,
      fromBlock: from_block,
      toBlock: to_block,
      offset: @max_page_offset
    }

    case GetLogs.focus(params) do
      {:ok, %{result: raw_logs}} when is_list(raw_logs) ->
        events =
          raw_logs
          |> Enum.map(fn raw -> Event.from_raw(raw, sub.chain_id) end)
          |> Enum.filter(fn event ->
            # Filter by event signatures if subscription has them
            if sub.event_signatures do
              Enum.any?(sub.event_signatures, fn sig ->
                Decoder.event_signature_to_topic(sig) == event.topic0
              end)
            else
              true
            end
          end)
          |> decode_events(sub)

        {:ok, events}

      {:error, error} ->
        {:error, error}

      _ ->
        {:ok, []}
    end
  end

  @doc """
  Decodes event data using the contract ABI.
  """
  @spec decode_events([Event.t()], Subscription.t()) :: [Event.t()]
  def decode_events(events, %Subscription{chain_id: chain_id, contract_address: contract} = sub) do
    abi = fetch_contract_abi(chain_id, contract)

    Enum.map(events, fn event ->
      abi_entry = find_matching_abi_entry(abi, event.topic0)

      decoded_params =
        case abi_entry do
          nil -> %{}
          entry -> Decoder.decode_event(event, entry)
        end

      %{event | decoded_params: decoded_params}
    end)
  end

  @doc """
  Fetches the contract ABI from Etherscan.
  """
  @spec fetch_contract_abi(pos_integer(), String.t()) :: [map()] | nil
  def fetch_contract_abi(chain_id, contract_address) do
    case Lux.Lenses.Etherscan.ContractAbi.focus(%{
           chainid: chain_id,
           address: contract_address
         }) do
      {:ok, %{result: abi}} when is_list(abi) -> abi
      {:ok, %{result: abi}} when is_map(abi) and Map.has_key?(abi, "abi") ->
        abi["abi"] || []

      _ ->
        nil
    end
  end

  @doc """
  Finds the ABI entry matching a topic0 hash.
  """
  @spec find_matching_abi_entry([map()] | nil, String.t()) :: map() | nil
  def find_matching_abi_entry(nil, _topic0), do: nil

  def find_matching_abi_entry(abi, topic0) when is_list(abi) do
    Enum.find(abi, fn entry ->
      entry["type"] == "event" and
        Decoder.event_signature_to_topic(event_sig_string(entry)) == topic0
    end)
  end

  defp event_sig_string(entry) do
    params = (entry["inputs"] || []) |> Enum.map(& &1["type"]) |> Enum.join(",")
    "#{entry["name"]}(#{params})"
  end

  @doc """
  Gets the latest block number for a chain by making a direct RPC call
  to Etherscan's block API with blocktag=latest.
  """
  @spec get_latest_block(pos_integer()) :: non_neg_integer()
  def get_latest_block(chain_id \ 1) do
    api_key = Lux.Config.etherscan_api_key()

    url = "https://api.etherscan.io/v2/api?chainid=#{chain_id}&module=block&action=getblockbybestnumber&tag=latest&apikey=#{api_key}"

    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        case body do
          %{"status" => "1", "result" => result} when is_map(result) ->
            case result["blockNumber"] do
              nil -> 0
              block -> Event.parse_hex_or_dec(block)
            end
          _ -> 0
        end

      _ ->
        0
    end
  end
end
