defmodule Mix.Tasks.Rust.Test do
  @shortdoc "Runs Rust tests"
  @moduledoc """
  Runs Rust tests using cargo test.

  ## Examples

      # Run all Rust tests
      mix rust.test

      # Run specific test suite or test
      mix rust.test test_name

      # Show test coverage
      mix rust.test --cov

  The task will use Cargo to run tests. Make sure you have Rust and Cargo installed.
  """

  use Mix.Task

  @requirements ["app.config"]

  defp safe_cmd(cmd, args, opts) do
    System.cmd(cmd, args, opts)
  rescue
    e in ErlangError ->
      case e do
        %ErlangError{original: :enoent} -> {:error, :not_found}
        _ -> reraise e, __STACKTRACE__
      end
  end

  @impl Mix.Task
  def run(args) do
    native_dir = Path.join(File.cwd!(), "native")

    # Only run tests if the native directory exists
    if File.dir?(native_dir) do
      # Find all cargo projects in the native directory
      cargo_projects = find_cargo_projects(native_dir)

      if Enum.empty?(cargo_projects) do
        Mix.shell().info("No Cargo.toml found in #{native_dir} or its subdirectories.")
      else
        Enum.each(cargo_projects, fn project_dir ->
          run_tests(project_dir, args)
        end)
      end
    else
      Mix.shell().info("No native directory found at #{native_dir}. Skipping Rust tests.")
    end
  end

  defp find_cargo_projects(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        Enum.reduce(files, [], fn file, acc ->
          path = Path.join(dir, file)

          cond do
            File.dir?(path) ->
              if File.exists?(Path.join(path, "Cargo.toml")) do
                [path | acc]
              else
                acc
              end

            true ->
              acc
          end
        end)
      _ ->
        []
    end
  end

  defp run_tests(project_dir, args) do
    project_name = Path.basename(project_dir)
    Mix.shell().info("\n==> Running Rust tests for #{project_name}")

    {cov?, args} = Enum.split_with(args, fn arg -> arg == "--cov" end)

    if cov? do
      run_coverage(project_dir, args)
    else
      cargo_args = ["test"] ++ args
      
      case safe_cmd("cargo", cargo_args,
             cd: project_dir,
             stderr_to_stdout: true,
             into: IO.stream()
           ) do
        {:error, :not_found} ->
          Mix.raise("Failed to execute Cargo command. Is Cargo installed?")

        {_, 0} ->
          :ok

        {_, status} ->
          Mix.raise("Rust tests failed for #{project_name} with status #{status}")
      end
    end
  end

  defp run_coverage(project_dir, args) do
    Mix.shell().info("Running coverage with cargo-tarpaulin...")
    
    cargo_args = ["tarpaulin", "--out", "Html", "--out", "Xml"] ++ args

    case safe_cmd("cargo", cargo_args,
           cd: project_dir,
           stderr_to_stdout: true,
           into: IO.stream()
         ) do
      {:error, :not_found} ->
        Mix.raise("""
        Failed to execute Cargo command or cargo-tarpaulin is not installed.
        Install it with: cargo install cargo-tarpaulin
        """)

      {_, 0} ->
        :ok

      {_, status} ->
        Mix.raise("Rust coverage failed for #{project_dir} with status #{status}")
    end
  end
end
