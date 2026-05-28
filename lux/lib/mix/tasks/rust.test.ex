defmodule Mix.Tasks.Rust.Test do
  @shortdoc "Runs Cargo tests for all Rust projects in the repository"
  @moduledoc """
  Discovers every `Cargo.toml` in the repository and runs `cargo test` in
  each project, formatting output the same way `mix test` does.

  ## Usage

      mix rust.test
      mix rust.test --dir priv/native/my_crate
      mix rust.test --release

  ## Options

    * `--dir PATH`    — test only the project at `PATH` (may be repeated)
    * `--release`     — compile with optimisations before testing
    * `--features F`  — comma-separated list of features to activate

  ## Exit behaviour

  Exits with a non-zero status when any Rust test suite has failures, so the
  task integrates cleanly with CI pipelines.
  """

  use Mix.Task

  alias Lux.Rust.Testing

  @green "\e[32m"
  @red "\e[31m"
  @yellow "\e[33m"
  @reset "\e[0m"

  @impl Mix.Task
  def run(args) do
    {opts, dirs, _} =
      OptionParser.parse(args,
        strict: [dir: [:string, :keep], release: :boolean, features: :string]
      )

    release = Keyword.get(opts, :release, false)

    features =
      case Keyword.get(opts, :features) do
        nil -> []
        f -> String.split(f, ",", trim: true)
      end

    run_opts = Keyword.merge([release: release, features: features], [])

    project_dirs =
      case dirs ++ Keyword.get_values(opts, :dir) do
        [] -> discover_rust_projects()
        explicit -> explicit
      end

    if project_dirs == [] do
      Mix.shell().info("#{@yellow}No Rust projects found.#{@reset}")
      :ok
    else
      results = Enum.map(project_dirs, &run_project(&1, run_opts))
      print_summary(results)
      if Enum.any?(results, fn {_dir, outcome} -> outcome == :fail end), do: exit({:shutdown, 1})
    end
  end

  # ── Discovery ────────────────────────────────────────────────────────────────

  defp discover_rust_projects do
    root = File.cwd!()

    root
    |> find_cargo_tomls()
    |> Enum.map(&Path.dirname/1)
    |> Enum.reject(&workspace_only?/1)
    |> Enum.sort()
  end

  defp find_cargo_tomls(root) do
    Path.wildcard(Path.join(root, "**/Cargo.toml"))
    |> Enum.reject(fn p ->
      String.contains?(p, "/target/") or String.contains?(p, "\\.target\\")
    end)
  end

  defp workspace_only?(dir) do
    toml_path = Path.join(dir, "Cargo.toml")

    case File.read(toml_path) do
      {:ok, content} ->
        String.contains?(content, "[workspace]") and
          not String.contains?(content, "[package]")

      _ ->
        false
    end
  end

  # ── Per-project runner ───────────────────────────────────────────────────────

  defp run_project(dir, opts) do
    label = Path.relative_to(dir, File.cwd!())
    Mix.shell().info("\nRunning Rust tests in #{label} ...")

    case Testing.run_tests(dir, opts) do
      {:ok, result} ->
        print_result(label, result)
        outcome = if result.failed > 0, do: :fail, else: :pass
        {dir, outcome}

      {:error, reason} ->
        Mix.shell().error("#{@red}ERROR#{@reset} #{label}: #{reason}")
        {dir, :fail}
    end
  end

  # ── Formatting ───────────────────────────────────────────────────────────────

  defp print_result(label, result) do
    status_color = if result.failed == 0, do: @green, else: @red
    status_text = if result.failed == 0, do: "ok", else: "FAILED"

    Mix.shell().info(
      "#{status_color}#{label}#{@reset}: " <>
        "#{result.passed} passed, #{result.failed} failed, " <>
        "#{result.ignored} ignored (#{result.duration_ms}ms) — #{status_color}#{status_text}#{@reset}"
    )
  end

  defp print_summary(results) do
    total = length(results)
    failed = Enum.count(results, fn {_d, o} -> o == :fail end)
    passed = total - failed

    Mix.shell().info("\n" <> String.duplicate("─", 60))

    if failed == 0 do
      Mix.shell().info("#{@green}All #{total} Rust project(s) passed.#{@reset}")
    else
      Mix.shell().info(
        "#{@red}#{failed} of #{total} Rust project(s) had failures (#{passed} passed).#{@reset}"
      )
    end
  end
end
