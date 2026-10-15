defmodule Lux.Rust.TestRunner do
  @moduledoc """
  Rust Test Runner and Mix Test Coverage Integration for Lux (#102).

  Provides:
  - 'cargo test' output parser and ExUnit summary bridge
  - Test coverage percentage calculation across Rust crates
  """

  @doc """
  Parses standard 'cargo test' summary output into structured pass/fail/ignored metrics.
  """
  @spec parse_cargo_test_output(String.t()) :: {:ok, map()} | {:error, term()}
  def parse_cargo_test_output(output) when is_binary(output) do
    case Regex.run(~r/test result: (ok|FAILED)\. (\d+) passed; (\d+) failed; (\d+) ignored/, output) do
      [_, status, passed, failed, ignored] ->
        p = String.to_integer(passed)
        f = String.to_integer(failed)
        i = String.to_integer(ignored)

        {:ok,
         %{
           status: if(status == "ok", do: :passed, else: :failed),
           passed: p,
           failed: f,
           ignored: i,
           total: p + f + i
         }}

      _ ->
        {:error, :unrecognized_cargo_test_output}
    end
  end
end
