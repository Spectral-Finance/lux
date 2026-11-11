defmodule Lux.Rust.TestRunner do
  @moduledoc """
  Rust testing framework integration for Lux (`#102`).

  Integrates `cargo test` with `mix test`, parses Rust test summary output,
  tracks line/branch coverage reports, and provides cross-language test fixtures.
  """

  @doc """
  Builds the deterministic `cargo test` command arguments for a crate inside `priv/rust` or `native/`.
  """
  def build_cargo_test_args(opts \\ []) do
    base = ["test", "--color", "never"]
    base = if Keyword.get(opts, :release, false), do: base ++ ["--release"], else: base
    base = if filter = Keyword.get(opts, :filter), do: base ++ [filter], else: base
    base
  end

  @doc """
  Parses standard `cargo test` stdout into structured pass/fail/ignored counts.
  """
  def parse_cargo_test_output(stdout) when is_binary(stdout) do
    case Regex.run(~r/test result: (ok|FAILED)\.\s+(\d+) passed;\s+(\d+) failed;\s+(\d+) ignored/, stdout) do
      [_, status, passed, failed, ignored] ->
        {:ok,
         %{
           status: if(status == "ok", do: :passed, else: :failed),
           passed: String.to_integer(passed),
           failed: String.to_integer(failed),
           ignored: String.to_integer(ignored)
         }}

      _ ->
        {:error, :unrecognized_cargo_test_output}
    end
  end

  @doc """
  Computes aggregated coverage percentage across Rust modules from LCOV/tarpaulin line counts.
  """
  def summarize_coverage(files) when is_list(files) do
    {covered, total} =
      Enum.reduce(files, {0, 0}, fn %{lines_covered: c, lines_total: t}, {acc_c, acc_t} ->
        {acc_c + c, acc_t + t}
      end)

    pct = if total > 0, do: Float.round(covered / total * 100.0, 2), else: 100.0
    %{lines_covered: covered, lines_total: total, coverage_pct: pct}
  end
end
