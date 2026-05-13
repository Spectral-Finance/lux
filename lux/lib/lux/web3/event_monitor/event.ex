defmodule Lux.Web3.EventMonitor.Event do
  @moduledoc """
  Normalized smart-contract event captured from an RPC log.
  """

  defstruct subscription_id: nil,
            chain_id: nil,
            contract_address: nil,
            block_number: nil,
            transaction_hash: nil,
            log_index: nil,
            topics: [],
            data: "0x",
            decoded: %{},
            metadata: %{}

  @type t :: %__MODULE__{
          subscription_id: String.t() | nil,
          chain_id: pos_integer(),
          contract_address: String.t(),
          block_number: non_neg_integer(),
          transaction_hash: String.t(),
          log_index: non_neg_integer(),
          topics: [String.t()],
          data: String.t(),
          decoded: map(),
          metadata: map()
        }

  @doc """
  Converts an Ethereum JSON-RPC log into a normalized event struct.
  """
  @spec from_log(map(), keyword()) :: {:ok, t()} | {:error, String.t()}
  def from_log(log, opts \\ []) when is_map(log) do
    with {:ok, chain_id} <- required_integer(opts, :chain_id),
         {:ok, address} <- required_address(log, "address"),
         {:ok, block_number} <- block_number(log),
         {:ok, tx_hash} <- required_binary(log, "transactionHash"),
         {:ok, log_index} <- log_index(log),
         {:ok, topics} <- topics(log),
         {:ok, data} <- data(log) do
      {:ok,
       %__MODULE__{
         subscription_id: Keyword.get(opts, :subscription_id),
         chain_id: chain_id,
         contract_address: address,
         block_number: block_number,
         transaction_hash: String.downcase(tx_hash),
         log_index: log_index,
         topics: topics,
         data: data,
         decoded: Keyword.get(opts, :decoded, %{}),
         metadata: Keyword.get(opts, :metadata, %{})
       }}
    end
  end

  def event_key(%__MODULE__{chain_id: chain_id, transaction_hash: tx_hash, log_index: log_index}) do
    {chain_id, tx_hash, log_index}
  end

  defp required_integer(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, value} when is_integer(value) and value > 0 -> {:ok, value}
      _ -> {:error, "#{key} must be a positive integer"}
    end
  end

  defp required_address(log, key) do
    case Map.fetch(log, key) do
      {:ok, address} when is_binary(address) ->
        normalized = String.downcase(address)

        if ethereum_address?(normalized) do
          {:ok, normalized}
        else
          {:error, "#{key} must be a hex Ethereum address"}
        end

      _ ->
        {:error, "#{key} must be a hex Ethereum address"}
    end
  end

  defp required_binary(log, key) do
    case Map.fetch(log, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "#{key} is required"}
    end
  end

  defp block_number(log), do: hex_or_integer(log, "blockNumber")
  defp log_index(log), do: hex_or_integer(log, "logIndex")

  defp hex_or_integer(log, key) do
    case Map.fetch(log, key) do
      {:ok, value} when is_integer(value) and value >= 0 -> {:ok, value}
      {:ok, "0x" <> _ = value} -> parse_hex(value, key)
      _ -> {:error, "#{key} must be a non-negative integer or hex quantity"}
    end
  end

  defp parse_hex("0x" <> rest, key) do
    case Integer.parse(rest, 16) do
      {value, ""} when value >= 0 -> {:ok, value}
      _ -> {:error, "#{key} must be a valid hex quantity"}
    end
  end

  defp topics(log) do
    case Map.get(log, "topics", []) do
      topics when is_list(topics) -> {:ok, Enum.map(topics, &String.downcase/1)}
      _ -> {:error, "topics must be a list"}
    end
  end

  defp data(log) do
    case Map.get(log, "data", "0x") do
      value when is_binary(value) -> {:ok, String.downcase(value)}
      _ -> {:error, "data must be a hex string"}
    end
  end

  defp ethereum_address?("0x" <> rest), do: byte_size(rest) == 40 and String.match?(rest, ~r/^[0-9a-f]+$/)
  defp ethereum_address?(_address), do: false
end
