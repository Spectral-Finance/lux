defmodule Lux.Rust.TestRunner do
  @moduledoc """
  Cargo-backed Rust test runner for Lux.

  The runner is intentionally independent from any particular Rust NIF bridge.
  It can run tests for `priv/rust` once that project exists, and tests can pass a
  custom `:project_path` for fixtures, examples, or generated Rust projects.
  """

  @type result :: %{
          status: :ok | :failed,
          passed: non_neg_integer(),
          failed: non_neg_integer(),
          ignored: non_neg_integer(),
          measured: non_neg_integer(),
          filtered_out: non_neg_integer(),
          command: [String.t()],
          output: String.t()
        }

  @doc """
  Runs `cargo test` for a Rust project.

  Options:

    * `:project_path` - path containing `Cargo.toml`, defaults to `priv/rust`
    * `:filter` - optional cargo test filter
    * `:verbose` - passes `-- --nocapture`
    * `:cargo` - cargo executable, defaults to `cargo`
    * `:env` - extra environment variables for `System.cmd/3`
  """
  @spec run(keyword()) :: {:ok, result()} | {:error, result() | String.t()}
  def run(opts \\ []) do
    project_path = project_path(opts)

    with :ok <- ensure_cargo_project(project_path) do
      cargo = Keyword.get(opts, :cargo, "cargo")
      args = cargo_test_args(opts)

      {output, exit_code} =
        System.cmd(cargo, args,
          cd: project_path,
          env: Keyword.get(opts, :env, []),
          stderr_to_stdout: true
        )

      result =
        output
        |> parse_results()
        |> Map.put(:command, [cargo | args])
        |> Map.put(:output, output)

      if exit_code == 0 and result.failed == 0 do
        {:ok, result}
      else
        {:error, %{result | status: :failed}}
      end
    end
  end

  @doc """
  Generates a grcov command plan for Rust coverage reporting.
  """
  @spec coverage_plan(keyword()) :: %{
          project_path: String.t(),
          env: [{String.t(), String.t()}],
          command: [String.t()]
        }
  def coverage_plan(opts \\ []) do
    project_path = project_path(opts)
    output = Keyword.get(opts, :output, "cover/rust/lcov.info")
    format = Keyword.get(opts, :format, "lcov")

    %{
      project_path: project_path,
      env: [
        {"CARGO_INCREMENTAL", "0"},
        {"RUSTFLAGS", "-Cinstrument-coverage"},
        {"LLVM_PROFILE_FILE", "target/coverage/lux-rust-%p-%m.profraw"}
      ],
      command: [
        "grcov",
        ".",
        "--binary-path",
        "target/debug/deps",
        "-s",
        ".",
        "-t",
        format,
        "--branch",
        "--ignore-not-existing",
        "-o",
        output
      ]
    }
  end

  @doc """
  Parses `cargo test` output into a compact result map.
  """
  @spec parse_results(String.t()) :: result()
  def parse_results(output) do
    captures =
      Regex.named_captures(
        ~r/test result: (?<status>\w+)\. (?<passed>\d+) passed; (?<failed>\d+) failed; (?<ignored>\d+) ignored; (?<measured>\d+) measured; (?<filtered>\d+) filtered out;/,
        output
      ) || %{}

    %{
      status: if(Map.get(captures, "status") == "ok", do: :ok, else: :failed),
      passed: integer_capture(captures, "passed"),
      failed: integer_capture(captures, "failed"),
      ignored: integer_capture(captures, "ignored"),
      measured: integer_capture(captures, "measured"),
      filtered_out: integer_capture(captures, "filtered"),
      command: [],
      output: output
    }
  end

  defp cargo_test_args(opts) do
    filter = Keyword.get(opts, :filter)
    verbose = Keyword.get(opts, :verbose, false)

    ["test"]
    |> maybe_append(filter)
    |> maybe_append_verbose(verbose)
  end

  defp maybe_append(args, nil), do: args
  defp maybe_append(args, ""), do: args
  defp maybe_append(args, filter), do: args ++ [to_string(filter)]

  defp maybe_append_verbose(args, true), do: args ++ ["--", "--nocapture"]
  defp maybe_append_verbose(args, _), do: args

  defp ensure_cargo_project(project_path) do
    if File.exists?(Path.join(project_path, "Cargo.toml")) do
      :ok
    else
      {:error, "No Cargo.toml found at #{project_path}"}
    end
  end

  defp project_path(opts) do
    opts
    |> Keyword.get(:project_path, Path.join(File.cwd!(), "priv/rust"))
    |> Path.expand()
  end

  defp integer_capture(captures, key) do
    captures
    |> Map.get(key, "0")
    |> String.to_integer()
  end
end
