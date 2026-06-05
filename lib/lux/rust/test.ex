defmodule Lux.Rust.Test do
  @moduledoc """
  Rust testing framework integration for native test execution.

  This module provides a pure-Elixir fallback test runner when the Rust NIF
  (`lux_rust`) is not compiled. It supports unit, integration, and benchmark
  test suites, allowing development and CI to proceed without native dependencies.

  ## Test Types

    * `:unit` - Quick, isolated tests for individual functions/modules
    * `:integration` - Tests that exercise multiple components together
    * `:benchmark` - Performance measurement tests

  ## Usage

      suite = %{
        type: "unit",
        name: "my_test_suite",
        tests: [
          %{name: "test_addition", fn: fn -> 1 + 1 == 2 end},
          %{name: "test_string", fn: fn -> String.length("hello") == 5 end}
        ]
      }

      Lux.Rust.Test.run_tests(suite)
      # => {:ok, %{passed: 2, failed: 0, total: 2}}

  When the Rust NIF is available, tests are delegated to the native `lux_rust` crate.
  """

  @doc """
  Run a test suite with the given configuration.

  ## Parameters

    - `test_suite` - A map with test suite details:
      * `:type` - `"unit"`, `"integration"`, or `"benchmark"`
      * `:name` - Suite name
      * `:tests` - List of test case maps
    - `config` - Optional configuration map (defaults to %{})

  ## Returns

    - `{:ok, %{passed: pos_integer, failed: pos_integer, total: pos_integer}}` on success
    - `{:error, String.t()}` on failure
  """
  @spec run_tests(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run_tests(test_suite, config \\\\ %{})

  def run_tests(%{type: type} = suite, config) when is_map(suite) and is_map(config) do
    case type do
      "unit" -> run_unit_tests(suite, config)
      "integration" -> run_integration_tests(suite, config)
      "benchmark" -> run_benchmarks(suite, config)
      other -> {:error, "Unknown test type: #{other}"}
    end
  end

  def run_tests(_, _), do: {:error, "Invalid test suite: expected a map with a :type key"}

  @doc """
  Run unit tests with a pure-Elixir fallback.

  Executes each test function and collects pass/fail results.

  ## Test Configuration

    * `:timeout` - Max milliseconds per test (default: 5000)
    * `:parallel` - Run tests in parallel (default: false)

  """
  @spec run_unit_tests(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run_unit_tests(suite, config \\\\ %{})

  def run_unit_tests(suite, config) do
    timeout = Map.get(config, :timeout, 5_000)
    tests = Map.get(suite, :tests, [])

    results =
      Enum.map(tests, fn test ->
        try do
          task =
            Task.async(fn ->
              test_fn = Map.get(test, :fn, fn -> true end)
              test_fn.()
            end)

          case Task.yield(task, timeout) || Task.shutdown(task) do
            {:ok, result} ->
              if result do
                :pass
              else
                {:fail, Map.get(test, :name, "unnamed"), "Test returned false"}
              end

            nil ->
              {:fail, Map.get(test, :name, "unnamed"), "Test timed out after #{timeout}ms"}
          end
        catch
          kind, reason ->
            {:fail, Map.get(test, :name, "unnamed"), "#{kind}: #{inspect(reason)}"}
        end
      end)

    passed = Enum.count(results, &(&1 == :pass))
    failed = Enum.count(results, &(not match?(:pass, &1)))

    if failed == 0 do
      {:ok, %{passed: passed, failed: failed, total: passed + failed}}
    else
      failures = Enum.filter(results, &(not match?(:pass, &1)))
      {:ok, %{passed: passed, failed: failed, total: passed + failed, failures: failures}}
    end
  end

  @doc """
  Run integration tests.

  Integration tests follow the same execution model as unit tests but
  may include additional setup/teardown steps defined in the suite config.

  ## Test Configuration

    * `:setup` - Function to run before all tests
    * `:teardown` - Function to run after all tests

  """
  @spec run_integration_tests(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run_integration_tests(suite, config \\\\ %{})

  def run_integration_tests(suite, config) do
    # Run optional setup
    if setup_fn = Map.get(config, :setup) do
      case setup_fn.() do
        :ok -> :ok
        {:error, reason} -> return {:error, "Integration setup failed: #{reason}"}
      end
    end

    result = run_unit_tests(suite, config)

    # Run optional teardown
    if teardown_fn = Map.get(config, :teardown) do
      teardown_fn.()
    end

    result
  end

  @doc """
  Run benchmark tests.

  Benchmarks execute each test multiple times and return timing statistics.

  ## Test Configuration

    * `:iterations` - Number of iterations per benchmark (default: 100)
    * `:warmup` - Number of warmup iterations (default: 10)

  """
  @spec run_benchmarks(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run_benchmarks(suite, config \\\\ %{})

  def run_benchmarks(suite, config) do
    iterations = Map.get(config, :iterations, 100)
    warmup = Map.get(config, :warmup, 10)
    tests = Map.get(suite, :tests, [])

    results =
      Enum.map(tests, fn test ->
        test_fn = Map.get(test, :fn, fn -> :ok end)
        name = Map.get(test, :name, "unnamed")

        # Warmup phase
        Enum.each(1..warmup, fn _ -> test_fn.() end)

        # Timed iterations
        {duration, _} =
          :timer.tc(fn ->
            Enum.each(1..iterations, fn _ -> test_fn.() end)
          end)

        avg_us = div(duration, iterations)

        %{
          name: name,
          total_time_us: duration,
          iterations: iterations,
          avg_time_us: avg_us,
          ops_per_sec: div(1_000_000, max(avg_us, 1))
        }
      end)

    {:ok, %{benchmarks: results}}
  end

  @doc false
  def version do
    %{major: 0, minor: 1, feature: :elixir_fallback}
  end
end
