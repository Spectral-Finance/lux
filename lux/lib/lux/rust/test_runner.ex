defmodule Lux.Rust.TestRunner do
  @moduledoc """
  Testing framework and test runner integration for Rust in Lux.

  Enables executing Rust unit and integration tests via `cargo test`, parsing output into
  structured results for `mix test` reporting, and generating cross-language test fixtures.

  ## Examples

      iex> output = "test result: ok. 5 passed; 0 failed; 1 ignored; 0 measured; 0 filtered out"
      iex> {:ok, summary} = Lux.Rust.TestRunner.parse_test_summary(output)
      iex> summary.passed
      5
  """

  require Logger

  defmodule Summary do
    @moduledoc """
    Summary of executed Rust tests.
    """
    @type t :: %__MODULE__{
            status: :ok | :failed,
            passed: integer(),
            failed: integer(),
            ignored: integer(),
            measured: integer(),
            filtered_out: integer(),
            raw_output: String.t()
          }

    defstruct status: :ok,
              passed: 0,
              failed: 0,
              ignored: 0,
              measured: 0,
              filtered_out: 0,
              raw_output: ""
  end

  @doc """
  Executes `cargo test` in the specified directory and parses results.
  """
  def run(project_dir, opts \\ []) do
    nocapture = Keyword.get(opts, :nocapture, true)
    test_filter = Keyword.get(opts, :test_filter, nil)

    args = ["test"]
    args = if test_filter, do: args ++ [test_filter], else: args
    args = if nocapture, do: args ++ ["--", "--nocapture"], else: args

    env = [
      {"RUST_BACKTRACE", "1"},
      {"CARGO_HOME", Lux.Rust.Cargo.cache_dir()}
    ]

    case System.cmd("cargo", args, cd: project_dir, env: env, stderr_to_stdout: true) do
      {output, 0} ->
        {:ok, build_summary(:ok, output)}

      {output, _code} ->
        {:error, build_summary(:failed, output)}
    end
  rescue
    e ->
      {:error, {:system_error, Exception.message(e)}}
  end

  @doc """
  Parses the standard `cargo test` summary line.
  """
  def parse_test_summary(output) when is_binary(output) do
    regex = ~r/test result: (ok|FAILED)\. (\d+) passed; (\d+) failed; (\d+) ignored; (\d+) measured; (\d+) filtered out/

    case Regex.run(regex, output) do
      [_, status_str, passed, failed, ignored, measured, filtered] ->
        status = if status_str == "ok", do: :ok, else: :failed

        {:ok,
         %Summary{
           status: status,
           passed: String.to_integer(passed),
           failed: String.to_integer(failed),
           ignored: String.to_integer(ignored),
           measured: String.to_integer(measured),
           filtered_out: String.to_integer(filtered),
           raw_output: output
         }}

      nil ->
        {:error, :summary_not_found}
    end
  end

  @doc """
  Generates a Rust unit test module (`#[cfg(test)] mod tests`) for a given component.
  """
  def generate_test_fixture(component_name, test_cases) when is_binary(component_name) and is_list(test_cases) do
    tests_str =
      Enum.map(test_cases, fn {test_name, input_json, expected_json} ->
        test_fn_name = Macro.underscore("test_#{test_name}")

        """
            #[test]
            fn #{test_fn_name}() {
                let input: serde_json::Value = serde_json::from_str(r#"#{input_json}"#).unwrap();
                let expected: serde_json::Value = serde_json::from_str(r#"#{expected_json}"#).unwrap();
                let result = #{component_name}::run(&input).expect("Execution failed");
                assert_eq!(result, expected);
            }
        """
        |> String.trim_trailing()
      end)
      |> Enum.join("\n\n")

    """
    #[cfg(test)]
    mod tests {
        use super::*;

    #{tests_str}
    }
    """
    |> String.trim()
  end

  defp build_summary(status, output) do
    case parse_test_summary(output) do
      {:ok, summary} -> summary
      {:error, _} -> %Summary{status: status, raw_output: output}
    end
  end
end
