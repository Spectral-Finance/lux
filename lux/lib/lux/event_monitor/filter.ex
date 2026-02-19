defmodule Lux.EventMonitor.Filter do
  @moduledoc """
  Provides event filtering and pattern matching for smart contract events.

  Filters can match events based on:
  - Contract address
  - Event name
  - Topic values
  - Decoded parameter values
  - Block number ranges
  - Custom predicate functions

  ## Filter Specification

  A filter is a map with optional keys:

      %{
        address: "0x...",            # Match specific contract address
        event_name: "Transfer",      # Match specific event name
        topics: ["0x...", nil, ...],  # Match specific topic values (nil = wildcard)
        params: %{                   # Match decoded parameter values
          "from" => "0x...",
          "value" => {:gt, 1000}     # Comparison operators
        },
        from_block: 1000,            # Minimum block number
        to_block: 2000,              # Maximum block number
        chain_id: 1,                 # Match specific chain
        predicate: fn log -> ... end # Custom predicate function
      }

  ## Parameter Matching

  Parameter values can be matched with:
  - Exact value: `"from" => "0xabc..."`
  - Greater than: `"value" => {:gt, 1000}`
  - Less than: `"value" => {:lt, 1000}`
  - Greater or equal: `"value" => {:gte, 1000}`
  - Less or equal: `"value" => {:lte, 1000}`
  - In list: `"status" => {:in, [1, 2, 3]}`
  - Not equal: `"from" => {:neq, "0x000..."}`
  - Regex: `"name" => {:regex, ~r/^Transfer/}`
  """

  alias Lux.EventMonitor.EventLog

  @type comparison ::
          {:gt, number()}
          | {:lt, number()}
          | {:gte, number()}
          | {:lte, number()}
          | {:in, list()}
          | {:neq, any()}
          | {:regex, Regex.t()}

  @type filter_spec :: %{
          optional(:address) => String.t(),
          optional(:event_name) => String.t() | [String.t()],
          optional(:topics) => [String.t() | nil],
          optional(:params) => %{String.t() => any() | comparison()},
          optional(:from_block) => non_neg_integer(),
          optional(:to_block) => non_neg_integer(),
          optional(:chain_id) => pos_integer(),
          optional(:predicate) => (EventLog.t() -> boolean())
        }

  @doc """
  Checks if an event log matches the given filter specification.

  ## Parameters

    * `event_log` - The event log to check
    * `filter` - A filter specification map

  ## Returns

  `true` if the event log matches all filter criteria, `false` otherwise.

  ## Examples

      iex> log = %EventLog{address: "0xdead...", event_name: "Transfer", block_number: 100}
      iex> Lux.EventMonitor.Filter.matches?(log, %{event_name: "Transfer"})
      true

      iex> Lux.EventMonitor.Filter.matches?(log, %{event_name: "Approval"})
      false
  """
  @spec matches?(EventLog.t(), filter_spec()) :: boolean()
  def matches?(%EventLog{} = event_log, filter) when is_map(filter) do
    Enum.all?(filter, fn {key, value} ->
      check_criterion(event_log, key, value)
    end)
  end

  def matches?(_, _), do: false

  @doc """
  Filters a list of event logs using the given filter specification.

  ## Parameters

    * `logs` - A list of EventLog structs
    * `filter` - A filter specification map

  ## Returns

  A list of event logs that match all filter criteria.

  ## Examples

      iex> logs = [log1, log2, log3]
      iex> Lux.EventMonitor.Filter.filter_logs(logs, %{event_name: "Transfer"})
      [log1, log3]
  """
  @spec filter_logs([EventLog.t()], filter_spec()) :: [EventLog.t()]
  def filter_logs(logs, filter) when is_list(logs) and is_map(filter) do
    Enum.filter(logs, &matches?(&1, filter))
  end

  @doc """
  Combines multiple filters with AND logic.

  An event must match ALL filters to be included.
  """
  @spec all_of([filter_spec()]) :: filter_spec()
  def all_of(filters) when is_list(filters) do
    %{predicate: fn log -> Enum.all?(filters, &matches?(log, &1)) end}
  end

  @doc """
  Combines multiple filters with OR logic.

  An event must match at least ONE filter to be included.
  """
  @spec any_of([filter_spec()]) :: filter_spec()
  def any_of(filters) when is_list(filters) do
    %{predicate: fn log -> Enum.any?(filters, &matches?(log, &1)) end}
  end

  # Individual criterion checks

  defp check_criterion(%EventLog{address: addr}, :address, expected) do
    String.downcase(addr) == String.downcase(expected)
  end

  defp check_criterion(%EventLog{event_name: name}, :event_name, expected) when is_binary(expected) do
    name == expected
  end

  defp check_criterion(%EventLog{event_name: name}, :event_name, expected) when is_list(expected) do
    name in expected
  end

  defp check_criterion(%EventLog{} = log, :topics, expected) when is_list(expected) do
    EventLog.matches_topics?(log, expected)
  end

  defp check_criterion(%EventLog{decoded_params: nil}, :params, _), do: false

  defp check_criterion(%EventLog{decoded_params: params}, :params, expected) when is_map(expected) do
    Enum.all?(expected, fn {key, matcher} ->
      value = Map.get(params, key) || Map.get(params, to_string(key))
      match_value?(value, matcher)
    end)
  end

  defp check_criterion(%EventLog{block_number: block}, :from_block, min_block) do
    block >= min_block
  end

  defp check_criterion(%EventLog{block_number: block}, :to_block, max_block) do
    block <= max_block
  end

  defp check_criterion(%EventLog{chain_id: chain}, :chain_id, expected_chain) do
    chain == expected_chain
  end

  defp check_criterion(%EventLog{} = log, :predicate, func) when is_function(func, 1) do
    func.(log)
  end

  defp check_criterion(_, _, _), do: true

  # Value matching with comparison operators

  defp match_value?(value, {:gt, threshold}) when is_number(value) and is_number(threshold) do
    value > threshold
  end

  defp match_value?(value, {:lt, threshold}) when is_number(value) and is_number(threshold) do
    value < threshold
  end

  defp match_value?(value, {:gte, threshold}) when is_number(value) and is_number(threshold) do
    value >= threshold
  end

  defp match_value?(value, {:lte, threshold}) when is_number(value) and is_number(threshold) do
    value <= threshold
  end

  defp match_value?(value, {:in, list}) when is_list(list) do
    value in list
  end

  defp match_value?(value, {:neq, expected}) do
    value != expected
  end

  defp match_value?(value, {:regex, regex}) when is_binary(value) do
    Regex.match?(regex, value)
  end

  defp match_value?(value, expected) do
    value == expected
  end
end
