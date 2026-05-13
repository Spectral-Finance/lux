defmodule Lux.Web3.EventMonitor.Subscription do
  @moduledoc """
  Describes a smart-contract event stream that Lux should monitor.

  A subscription keeps the reviewable, chain-agnostic parts of event
  monitoring in Elixir: chain id, contract address, event topics, block range,
  and webhook destination. Runtime adapters can later attach an RPC/WebSocket
  client without changing filtering or persistence semantics.
  """

  defstruct id: nil,
            chain_id: nil,
            contract_address: nil,
            event_name: nil,
            topics: [],
            from_block: 0,
            to_block: :latest,
            webhook_url: nil,
            metadata: %{}

  @type topic_filter :: nil | String.t() | [String.t()]

  @type t :: %__MODULE__{
          id: String.t(),
          chain_id: pos_integer(),
          contract_address: String.t(),
          event_name: String.t() | nil,
          topics: [topic_filter()],
          from_block: non_neg_integer(),
          to_block: non_neg_integer() | :latest,
          webhook_url: String.t() | nil,
          metadata: map()
        }

  @doc """
  Builds and validates a subscription.
  """
  @spec new(map() | keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(attrs) when is_list(attrs), do: attrs |> Map.new() |> new()

  def new(attrs) when is_map(attrs) do
    with {:ok, chain_id} <- fetch_positive_integer(attrs, :chain_id),
         {:ok, address} <- fetch_address(attrs, :contract_address),
         {:ok, from_block} <- fetch_block(attrs, :from_block, 0),
         {:ok, to_block} <- fetch_to_block(attrs),
         {:ok, topics} <- normalize_topics(Map.get(attrs, :topics, [])),
         :ok <- validate_block_range(from_block, to_block) do
      {:ok,
       %__MODULE__{
         id: Map.get(attrs, :id) || default_id(chain_id, address, topics),
         chain_id: chain_id,
         contract_address: address,
         event_name: Map.get(attrs, :event_name),
         topics: topics,
         from_block: from_block,
         to_block: to_block,
         webhook_url: Map.get(attrs, :webhook_url),
         metadata: Map.get(attrs, :metadata, %{})
       }}
    end
  end

  defp fetch_positive_integer(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, value} when is_integer(value) and value > 0 -> {:ok, value}
      {:ok, value} when is_binary(value) -> parse_positive_integer(value, key)
      _ -> {:error, "#{key} must be a positive integer"}
    end
  end

  defp parse_positive_integer(value, key) do
    case Integer.parse(value) do
      {parsed, ""} when parsed > 0 -> {:ok, parsed}
      _ -> {:error, "#{key} must be a positive integer"}
    end
  end

  defp fetch_address(attrs, key) do
    case Map.fetch(attrs, key) do
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

  defp fetch_block(attrs, key, default) do
    value = Map.get(attrs, key, default)

    case value do
      block when is_integer(block) and block >= 0 -> {:ok, block}
      block when is_binary(block) -> parse_non_negative_integer(block, key)
      _ -> {:error, "#{key} must be a non-negative integer"}
    end
  end

  defp fetch_to_block(attrs) do
    case Map.get(attrs, :to_block, :latest) do
      :latest -> {:ok, :latest}
      "latest" -> {:ok, :latest}
      value -> fetch_block(Map.put(%{}, :to_block, value), :to_block, 0)
    end
  end

  defp parse_non_negative_integer(value, key) do
    case Integer.parse(value) do
      {parsed, ""} when parsed >= 0 -> {:ok, parsed}
      _ -> {:error, "#{key} must be a non-negative integer"}
    end
  end

  defp normalize_topics(topics) when is_list(topics) do
    topics
    |> Enum.map(&normalize_topic_filter/1)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, topic}, {:ok, acc} -> {:cont, {:ok, [topic | acc]}}
      {:error, reason}, _ -> {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      error -> error
    end
  end

  defp normalize_topics(_topics), do: {:error, "topics must be a list"}

  defp normalize_topic_filter(nil), do: {:ok, nil}

  defp normalize_topic_filter(topic) when is_binary(topic) do
    if hex_topic?(topic), do: {:ok, String.downcase(topic)}, else: {:error, "topic must be a 32-byte hex string"}
  end

  defp normalize_topic_filter(topics) when is_list(topics) do
    with {:ok, normalized} <- normalize_topics(topics) do
      {:ok, normalized}
    end
  end

  defp normalize_topic_filter(_topic), do: {:error, "topic filter must be nil, a topic, or a list of topics"}

  defp validate_block_range(_from_block, :latest), do: :ok
  defp validate_block_range(from_block, to_block) when from_block <= to_block, do: :ok
  defp validate_block_range(_from_block, _to_block), do: {:error, "from_block cannot be greater than to_block"}

  defp ethereum_address?("0x" <> rest), do: byte_size(rest) == 40 and String.match?(rest, ~r/^[0-9a-f]+$/)
  defp ethereum_address?(_address), do: false

  defp hex_topic?(topic) when is_binary(topic) do
    case String.downcase(topic) do
      "0x" <> rest -> byte_size(rest) == 64 and String.match?(rest, ~r/^[0-9a-f]+$/)
      _ -> false
    end
  end

  defp hex_topic?(_topic), do: false

  defp default_id(chain_id, address, topics) do
    hash =
      :crypto.hash(:sha256, :erlang.term_to_binary({chain_id, address, topics}))
      |> Base.encode16(case: :lower)
      |> binary_part(0, 12)

    "contract-events-#{hash}"
  end
end
