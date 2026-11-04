defmodule Lux.Rust.TestRunner do
  @moduledoc """
  Cross-language Rust testing framework utilities, fixtures, coverage parser,
  and `ExUnit` integration helpers for Lux (`Spectral-Finance/lux#102`).
  """

  @fixture_table :lux_rust_test_fixtures

  @doc """
  Ensures the ETS table for cross-language test fixtures is initialized.
  """
  @spec ensure_started() :: :ok
  def ensure_started do
    case :ets.whereis(@fixture_table) do
      :undefined ->
        try do
          :ets.new(@fixture_table, [:named_table, :public, :set, read_concurrency: true])
        rescue
          ArgumentError -> :ok
        end

      _tid ->
        :ok
    end

    :ok
  end

  @doc """
  Registers a named cross-language test fixture serialized to JSON for both Elixir and Rust tests.
  """
  @spec create_fixture(atom() | String.t(), map()) :: {:ok, %{name: String.t(), json: String.t(), payload: map()}}
  def create_fixture(name, payload) when is_map(payload) do
    ensure_started()
    key = to_string(name)
    json = Jason.encode!(payload)
    record = %{name: key, json: json, payload: payload}
    :ets.insert(@fixture_table, {key, record})
    {:ok, record}
  end

  @doc """
  Loads a previously registered cross-language test fixture by name.
  """
  @spec load_fixture(atom() | String.t()) :: {:ok, map()} | {:error, :not_found}
  def load_fixture(name) do
    ensure_started()
    key = to_string(name)

    case :ets.lookup(@fixture_table, key) do
      [{^key, record}] -> {:ok, record}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Verifies cross-language output parity between an Elixir function and a Rust component handler
  given the same fixture input.
  """
  @spec assert_cross_language_parity(
          (map() -> {:ok, term()} | term()),
          (map() -> {:ok, term()} | term()),
          map()
        ) :: {:ok, %{matched: boolean(), elixir_output: term(), rust_output: term()}} | {:error, term()}
  def assert_cross_language_parity(elixir_fn, rust_fn, input)
      when is_function(elixir_fn, 1) and is_function(rust_fn, 1) and is_map(input) do
    ex_out = normalize_result(elixir_fn.(input))
    rs_out = normalize_result(rust_fn.(input))

    if ex_out == rs_out do
      {:ok, %{matched: true, elixir_output: ex_out, rust_output: rs_out}}
    else
      {:error, %{matched: false, elixir_output: ex_out, rust_output: rs_out}}
    end
  end

  defp normalize_result({:ok, val}), do: val
  defp normalize_result(val), do: val

  @doc """
  Parses `cargo test` and `cargo tarpaulin` stdout output into structured test and coverage metrics.
  """
  @spec parse_test_and_coverage_output(String.t()) :: %{
          passed: non_neg_integer(),
          failed: non_neg_integer(),
          ignored: non_neg_integer(),
          coverage_percent: float() | nil,
          status: :ok | :failed
        }
  def parse_test_and_coverage_output(output) when is_binary(output) do
    passed = extract_int(output, ~r/(\d+)\s+passed/)
    failed = extract_int(output, ~r/(\d+)\s+failed/)
    ignored = extract_int(output, ~r/(\d+)\s+ignored/)

    coverage =
      case Regex.run(~r/(\d+(?:\.\d+)?)%\s+coverage/i, output) do
        [_, pct] ->
          {val, _} = Float.parse(pct)
          val

        nil ->
          nil
      end

    %{
      passed: passed,
      failed: failed,
      ignored: ignored,
      coverage_percent: coverage,
      status: if(failed == 0, do: :ok, else: :failed)
    }
  end

  defp extract_int(text, regex) do
    case Regex.run(regex, text) do
      [_, digits] -> String.to_integer(digits)
      nil -> 0
    end
  end
end
