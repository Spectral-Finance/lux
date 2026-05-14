defmodule Lux.Rust.TestRunner do
  @moduledoc """
  Cargo test integration for Rust code used by Lux.

  The runner has two layers:

    * command planning, which is pure and useful in CI or agents
    * execution, which shells out to `cargo` only when requested

  Test output and LCOV parsing are kept independent from cargo execution so
  ExUnit can cover the framework without requiring a Rust toolchain.
  """

  @type test_summary :: %{
          status: :ok | :failed | :unknown | :missing_toolchain | :missing_manifest,
          passed: non_neg_integer(),
          failed: non_neg_integer(),
          ignored: non_neg_integer(),
          measured: non_neg_integer(),
          filtered_out: non_neg_integer(),
          failures: [String.t()]
        }

  @doc """
  Builds a cargo test command plan.

  Supported options:

    * `:cargo` - cargo executable, defaults to `"cargo"`
    * `:manifest_path` - explicit Cargo.toml path
    * `:package` - cargo package selector
    * `:features` - comma-separated features
    * `:all_features` - pass `--all-features`
    * `:no_default_features` - pass `--no-default-features`
    * `:release` - pass `--release`
    * `:jobs` - pass `--jobs N`
    * `:filter` - test name filter
    * `:no_capture` - pass `-- --nocapture`
    * `:coverage` - add LLVM coverage environment variables
  """
  @spec build_test_plan(Path.t(), keyword()) :: map()
  def build_test_plan(project_root, opts \\ []) do
    project_root = Path.expand(project_root)
    cargo = Keyword.get(opts, :cargo, "cargo")
    coverage? = Keyword.get(opts, :coverage, false)
    coverage_output = Keyword.get(opts, :coverage_output, Path.join(project_root, "cover/rust"))

    %{
      project_root: project_root,
      manifest_path: Keyword.get(opts, :manifest_path, Path.join(project_root, "Cargo.toml")),
      command: cargo,
      args: build_args(opts),
      env: build_env(coverage?, coverage_output, opts),
      coverage: coverage_plan(coverage?, coverage_output, opts)
    }
  end

  @doc """
  Runs cargo tests and returns a normalized summary.

  Pass `runner: fun` and `require_toolchain: false` in tests to avoid shelling
  out to cargo. The runner receives `{command, args, system_opts}`.
  """
  @spec run(Path.t(), keyword()) :: {:ok, map()} | {:error, map()}
  def run(project_root, opts \\ []) do
    plan = build_test_plan(project_root, opts)

    with :ok <- ensure_manifest(plan, opts),
         {:ok, command} <- resolve_cargo(plan.command, opts),
         {:ok, output, exit_status} <- run_command(command, plan, opts) do
      summary =
        output
        |> parse_test_output()
        |> Map.merge(%{
          output: output,
          exit_status: exit_status,
          command: [command | plan.args],
          project_root: plan.project_root,
          coverage: plan.coverage
        })

      if exit_status == 0 and summary.failed == 0 do
        {:ok, summary}
      else
        {:error, %{summary | status: :failed}}
      end
    else
      {:error, reason} ->
        {:error, error_summary(reason, plan)}
    end
  end

  @doc """
  Installs an ExUnit after-suite hook that runs Rust tests.

  This is opt-in. Add it to `test/test_helper.exs` when the project wants
  `mix test` to fail if the Rust crate fails.
  """
  @spec install_ex_unit_hook(keyword()) :: :ok
  def install_ex_unit_hook(opts \\ []) do
    ExUnit.after_suite(fn _results ->
      project_root = Keyword.get(opts, :project_root, Lux.Rust.project_path())

      case run(project_root, opts) do
        {:ok, summary} ->
          IO.puts(format_summary(summary))

        {:error, summary} ->
          raise "Rust tests failed: #{format_summary(summary)}"
      end
    end)

    :ok
  end

  @doc """
  Parses standard cargo test output.
  """
  @spec parse_test_output(String.t()) :: test_summary()
  def parse_test_output(output) when is_binary(output) do
    result_lines =
      Regex.scan(
        ~r/test result: (\w+)\. (\d+) passed; (\d+) failed; (\d+) ignored; (\d+) measured; (\d+) filtered out/s,
        output,
        capture: :all_but_first
      )

    totals =
      Enum.reduce(result_lines, empty_totals(), fn [
                                                     status,
                                                     passed,
                                                     failed,
                                                     ignored,
                                                     measured,
                                                     filtered
                                                   ],
                                                   acc ->
        %{
          acc
          | statuses: [status | acc.statuses],
            passed: acc.passed + to_int(passed),
            failed: acc.failed + to_int(failed),
            ignored: acc.ignored + to_int(ignored),
            measured: acc.measured + to_int(measured),
            filtered_out: acc.filtered_out + to_int(filtered)
        }
      end)

    failures =
      ~r/^test\s+(.+?)\s+\.\.\.\s+(?:FAILED|failed)$/m
      |> Regex.scan(output, capture: :all_but_first)
      |> List.flatten()
      |> Enum.uniq()

    status =
      cond do
        totals.failed > 0 or failures != [] -> :failed
        Enum.any?(totals.statuses, &(&1 == "ok")) -> :ok
        true -> :unknown
      end

    totals
    |> Map.drop([:statuses])
    |> Map.merge(%{status: status, failures: failures})
  end

  @doc """
  Parses LCOV content into aggregate totals and per-file summaries.
  """
  @spec parse_lcov(String.t()) :: map()
  def parse_lcov(content) when is_binary(content) do
    files =
      content
      |> String.split("end_of_record")
      |> Enum.map(&parse_lcov_record/1)
      |> Enum.reject(&is_nil/1)

    totals =
      Enum.reduce(
        files,
        %{lines_found: 0, lines_hit: 0, branches_found: 0, branches_hit: 0},
        fn file, acc ->
          %{
            lines_found: acc.lines_found + file.lines_found,
            lines_hit: acc.lines_hit + file.lines_hit,
            branches_found: acc.branches_found + file.branches_found,
            branches_hit: acc.branches_hit + file.branches_hit
          }
        end
      )

    Map.merge(totals, %{
      line_rate: ratio(totals.lines_hit, totals.lines_found),
      branch_rate: ratio(totals.branches_hit, totals.branches_found),
      files: files
    })
  end

  @doc """
  Formats a compact test summary for Mix tasks and ExUnit hooks.
  """
  @spec format_summary(map()) :: String.t()
  def format_summary(summary) do
    "Rust tests #{summary.status}: #{summary.passed} passed, #{summary.failed} failed, " <>
      "#{summary.ignored} ignored, #{summary.filtered_out} filtered"
  end

  defp build_args(opts) do
    cargo_args =
      []
      |> put_pair("--manifest-path", Keyword.get(opts, :manifest_path))
      |> put_pair("--package", Keyword.get(opts, :package))
      |> put_pair("--features", Keyword.get(opts, :features))
      |> put_flag("--all-features", Keyword.get(opts, :all_features, false))
      |> put_flag("--no-default-features", Keyword.get(opts, :no_default_features, false))
      |> put_flag("--release", Keyword.get(opts, :release, false))
      |> put_pair("--jobs", Keyword.get(opts, :jobs))

    test_args =
      []
      |> put_flag("--nocapture", Keyword.get(opts, :no_capture, false))
      |> put_pair("--test-threads", Keyword.get(opts, :test_threads))

    ["test"] ++ cargo_args ++ filter_args(opts) ++ separator_args(test_args)
  end

  defp filter_args(opts) do
    case Keyword.get(opts, :filter) do
      filter when is_binary(filter) and filter != "" -> [filter]
      _ -> []
    end
  end

  defp separator_args([]), do: []
  defp separator_args(args), do: ["--" | args]

  defp put_pair(args, _name, nil), do: args
  defp put_pair(args, _name, ""), do: args
  defp put_pair(args, name, value), do: args ++ [name, to_string(value)]

  defp put_flag(args, name, true), do: args ++ [name]
  defp put_flag(args, _name, _value), do: args

  defp build_env(false, _coverage_output, _opts), do: %{}

  defp build_env(true, coverage_output, opts) do
    profile =
      Keyword.get(opts, :profile_pattern, Path.join(coverage_output, "lux-rust-%p-%m.profraw"))

    %{
      "CARGO_INCREMENTAL" => "0",
      "LLVM_PROFILE_FILE" => profile,
      "RUSTFLAGS" => "-Cinstrument-coverage"
    }
  end

  defp coverage_plan(false, _coverage_output, _opts), do: %{enabled: false}

  defp coverage_plan(true, coverage_output, opts) do
    %{
      enabled: true,
      tool: Keyword.get(opts, :coverage_tool, :llvm_cov),
      output_dir: coverage_output,
      lcov_path: Keyword.get(opts, :lcov_path, Path.join(coverage_output, "lcov.info"))
    }
  end

  defp ensure_manifest(plan, opts) do
    if Keyword.get(opts, :skip_manifest_check, false) do
      :ok
    else
      do_ensure_manifest(plan)
    end
  end

  defp do_ensure_manifest(plan) do
    if File.exists?(plan.manifest_path), do: :ok, else: {:error, :missing_manifest}
  end

  defp resolve_cargo(cargo, opts) do
    if Keyword.get(opts, :require_toolchain, true) do
      case System.find_executable(cargo) do
        nil -> {:error, :missing_toolchain}
        path -> {:ok, path}
      end
    else
      {:ok, cargo}
    end
  end

  defp run_command(command, plan, opts) do
    runner = Keyword.get(opts, :runner, &System.cmd/3)
    if plan.coverage.enabled, do: File.mkdir_p!(plan.coverage.output_dir)

    system_opts = [
      cd: plan.project_root,
      env: Map.to_list(plan.env),
      stderr_to_stdout: true
    ]

    case runner.(command, plan.args, system_opts) do
      {output, exit_status} when is_binary(output) and is_integer(exit_status) ->
        {:ok, output, exit_status}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e in ErlangError ->
      case e do
        %ErlangError{original: :enoent} -> {:error, :missing_toolchain}
        _ -> reraise e, __STACKTRACE__
      end
  end

  defp error_summary(reason, plan) do
    %{
      status: reason,
      passed: 0,
      failed: 0,
      ignored: 0,
      measured: 0,
      filtered_out: 0,
      failures: [],
      output: "",
      exit_status: nil,
      command: [plan.command | plan.args],
      project_root: plan.project_root,
      coverage: plan.coverage
    }
  end

  defp empty_totals do
    %{statuses: [], passed: 0, failed: 0, ignored: 0, measured: 0, filtered_out: 0}
  end

  defp parse_lcov_record(record) do
    record = String.trim(record)

    if record == "" do
      nil
    else
      %{
        source: capture_first(record, ~r/^SF:(.+)$/m),
        lines_found: capture_int(record, ~r/^LF:(\d+)$/m),
        lines_hit: capture_int(record, ~r/^LH:(\d+)$/m),
        branches_found: capture_int(record, ~r/^BRF:(\d+)$/m),
        branches_hit: capture_int(record, ~r/^BRH:(\d+)$/m)
      }
      |> then(fn file ->
        Map.merge(file, %{
          line_rate: ratio(file.lines_hit, file.lines_found),
          branch_rate: ratio(file.branches_hit, file.branches_found)
        })
      end)
    end
  end

  defp capture_first(content, regex) do
    case Regex.run(regex, content, capture: :all_but_first) do
      [value] -> value
      _ -> nil
    end
  end

  defp capture_int(content, regex) do
    case capture_first(content, regex) do
      nil -> 0
      value -> to_int(value)
    end
  end

  defp ratio(_hit, 0), do: 0.0
  defp ratio(hit, found), do: Float.round(hit / found * 100, 2)

  defp to_int(value) when is_integer(value), do: value
  defp to_int(value), do: value |> to_string() |> String.to_integer()
end
