defmodule Lux.Web3.EventMonitor.Filter do
  @moduledoc """
  Declarative event filtering and pattern matching engine for smart contract
  events (`%Lux.Web3.EventMonitor.Decoder.DecodedEvent{}`).

  Supports filtering by chain, contract addresses, event names, positional topics,
  block ranges, and decoded parameter pattern predicates (`:eq`, `:neq`, `:gt`,
  `:gte`, `:lt`, `:lte`, `:in`, `:contains`, or custom functions).
  """

  alias Lux.Web3.EventMonitor.Decoder
  alias Lux.Web3.EventMonitor.Decoder.DecodedEvent

  @type pattern ::
          {:eq, term()}
          | {:neq, term()}
          | {:gt, number()}
          | {:gte, number()}
          | {:lt, number()}
          | {:lte, number()}
          | {:in, list()}
          | {:contains, String.t()}
          | (term() -> boolean())
          | term()

  @type t :: %__MODULE__{
          chains: [atom()] | nil,
          contracts: [String.t()] | nil,
          event_names: [String.t()] | nil,
          topics: [String.t() | [String.t()] | nil] | nil,
          from_block: non_neg_integer() | nil,
          to_block: non_neg_integer() | nil,
          param_patterns: %{optional(atom() | String.t()) => pattern()}
        }

  defstruct chains: nil,
            contracts: nil,
            event_names: nil,
            topics: nil,
            from_block: nil,
            to_block: nil,
            param_patterns: %{}

  @doc """
  Builds a normalized `%Filter{}` struct from a map or keyword list.
  """
  @spec new(map() | keyword() | t()) :: t()
  def new(%__MODULE__{} = filter), do: normalize(filter)

  def new(attrs) when is_map(attrs) or is_list(attrs) do
     __MODULE__
    |> struct(Map.new(attrs))
    |> normalize()
  end

  @doc """
  Evaluates whether a `%DecodedEvent{}` matches all criteria and parameter patterns
  in the given filter.
  """
  @spec matches?(DecodedEvent.t(), t() | map() | keyword()) :: boolean()
  def matches?(%DecodedEvent{} = event, filter) do
    f = new(filter)

    chain_matches?(event.chain, f.chains) and
      contract_matches?(event.contract_address, f.contracts) and
      event_name_matches?(event.event_name, f.event_names) and
      block_range_matches?(event.block_number, f.from_block, f.to_block) and
      topics_match?(event.topics, f.topics) and
      params_match?(event.params, f.param_patterns)
  end

  @doc """
  Constructs a JSON-RPC `eth_getLogs` filter payload from a `%Filter{}` and explicit
  block bounds.
  """
  @spec to_rpc_filter(
          t() | map(),
          non_neg_integer() | String.t(),
          non_neg_integer() | String.t()
        ) ::
          map()
  def to_rpc_filter(filter, from_block \\ "latest", to_block \\ "latest") do
    f = new(filter)

    base = %{
      "fromBlock" => format_block(from_block),
      "toBlock" => format_block(to_block)
    }

    base
    |> maybe_add_contracts(f.contracts)
    |> maybe_add_topics(f)
  end

  defp normalize(%__MODULE__{} = f) do
    contracts =
      case f.contracts do
        nil -> nil
        list -> list |> List.wrap() |> Enum.map(&String.downcase(to_string(&1)))
      end

    chains = if is_nil(f.chains), do: nil, else: List.wrap(f.chains)
    names = if is_nil(f.event_names), do: nil, else: List.wrap(f.event_names)

    %{f | contracts: contracts, chains: chains, event_names: names}
  end

  defp chain_matches?(_chain, nil), do: true
  defp chain_matches?(chain, chains), do: chain in chains

  defp contract_matches?(_addr, nil), do: true
  defp contract_matches?(nil, _contracts), do: false
  defp contract_matches?(addr, contracts), do: String.downcase(addr) in contracts

  defp event_name_matches?(_name, nil), do: true
  defp event_name_matches?(name, names), do: name in names

  defp block_range_matches?(num, from_b, to_b) do
    (is_nil(from_b) or num >= from_b) and (is_nil(to_b) or num <= to_b)
  end

  defp topics_match?(_event_topics, nil), do: true
  defp topics_match?(_event_topics, []), do: true

  defp topics_match?(event_topics, filter_topics) when is_list(filter_topics) do
    filter_topics
    |> Enum.with_index()
    |> Enum.all?(fn {criterion, idx} ->
      actual = Enum.at(event_topics, idx)
      topic_position_matches?(actual, criterion)
    end)
  end

  defp topic_position_matches?(_actual, nil), do: true
  defp topic_position_matches?(nil, _criterion), do: false

  defp topic_position_matches?(actual, criterion) when is_binary(criterion) do
    String.downcase(actual) == String.downcase(criterion)
  end

  defp topic_position_matches?(actual, criteria) when is_list(criteria) do
    down_actual = String.downcase(actual)
    Enum.any?(criteria, &(String.downcase(to_string(&1)) == down_actual))
  end

  defp params_match?(_params, nil), do: true
  defp params_match?(_params, patterns) when map_size(patterns) == 0, do: true

  defp params_match?(params, patterns) when is_map(patterns) do
    Enum.all?(patterns, fn {key, pattern} ->
      val = fetch_param(params, key)
      eval_pattern(val, pattern)
    end)
  end

  defp fetch_param(params, key) when is_atom(key) do
    Map.get(params, key) || Map.get(params, Atom.to_string(key))
  end

  defp fetch_param(params, key) when is_binary(key) do
    Map.get(params, key) ||
      Enum.find_value(params, fn
        {k, v} when is_atom(k) -> if Atom.to_string(k) == key, do: v
        _ -> nil
      end)
  end

  defp eval_pattern(val, {:eq, target}), do: normalize_cmp(val) == normalize_cmp(target)
  defp eval_pattern(val, {:neq, target}), do: normalize_cmp(val) != normalize_cmp(target)
  defp eval_pattern(val, {:gt, target}) when is_number(val), do: val > target
  defp eval_pattern(val, {:gte, target}) when is_number(val), do: val >= target
  defp eval_pattern(val, {:lt, target}) when is_number(val), do: val < target
  defp eval_pattern(val, {:lte, target}) when is_number(val), do: val <= target

  defp eval_pattern(val, {:in, list}) when is_list(list) do
    norm_val = normalize_cmp(val)
    Enum.any?(list, &(normalize_cmp(&1) == norm_val))
  end

  defp eval_pattern(val, {:contains, substr}) when is_binary(val) and is_binary(substr) do
    String.contains?(String.downcase(val), String.downcase(substr))
  end

  defp eval_pattern(val, fun) when is_function(fun, 1), do: fun.(val) == true
  defp eval_pattern(val, literal), do: normalize_cmp(val) == normalize_cmp(literal)

  defp normalize_cmp(v) when is_binary(v), do: String.downcase(v)
  defp normalize_cmp(v), do: v

  defp maybe_add_contracts(map, nil), do: map
  defp maybe_add_contracts(map, [single]), do: Map.put(map, "address", single)
  defp maybe_add_contracts(map, list), do: Map.put(map, "address", list)

  defp maybe_add_topics(map, %__MODULE__{topics: topics}) when is_list(topics) and topics != [] do
    Map.put(map, "topics", topics)
  end

  defp maybe_add_topics(map, %__MODULE__{event_names: names})
       when is_list(names) and names != [] do
    topic0s =
      Enum.flat_map(names, fn name ->
        case Decoder.lookup_abi(name) do
          {:ok, abi} -> [abi.topic0]
          _ -> []
        end
      end)

    case topic0s do
      [] -> map
      [single] -> Map.put(map, "topics", [single])
      multiple -> Map.put(map, "topics", [multiple])
    end
  end

  defp maybe_add_topics(map, _filter), do: map

  defp format_block(num) when is_integer(num) and num >= 0 do
    "0x" <> String.downcase(Integer.to_string(num, 16))
  end

  defp format_block(tag) when is_binary(tag), do: tag
end
