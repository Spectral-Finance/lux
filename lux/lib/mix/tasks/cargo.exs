defmodule Mix.Tasks.Cargo do
  @shortdoc "Runs Cargo commands for Rust package management"
  @moduledoc """
  Runs Cargo commands for Rust/Cargo package management in Lux.

  Delegates to the system `cargo` command in the priv/rust directory.
  Supports all standard Cargo subcommands.

  ## Examples

      # Build the Rust project
      mix cargo build

      # Run Rust tests
      mix cargo test

      # Check compilation
      mix cargo check

      # Build in release mode
      mix cargo build --release

      # Run with custom args
      mix cargo clippy -- -D warnings

  The task runs in `priv/rust/` by default.
  Use `--cd <path>` to specify a different working directory.
  """

  use Mix.Task

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {parsed, rest} = parse_args(args)
    work_dir = Keyword.get(parsed, :cd, Path.join(File.cwd!(), "priv/rust"))

    rest = if rest == [], do: ["--help"], else: rest

    case run_cargo(rest, work_dir) do
      {:ok, output} ->
        Mix.shell().info(output)

      {:error, output} ->
        Mix.shell().error(output)
        exit({:shutdown, 1})
    end
  end

  defp parse_args(args) do
    {parsed, rest, _invalid} =
      OptionParser.parse(args, aliases: [C: :cd], strict: [cd: :string])

    {parsed, rest}
  end

  defp run_cargo(args, work_dir) do
    case System.cmd("cargo", args, cd: work_dir, stderr_to_stdout: true, into: IO.stream()) do
      {:error, :enoent} ->
        {:error, "cargo not found in PATH. Ensure Rust toolchain is installed."}

      {_, 0} ->
        :ok

      {_, _} ->
        {:error, "Cargo command failed"}
    end
  rescue
    e in ErlangError ->
      case e do
        %ErlangError{original: :enoent} -> {:error, "cargo not found in PATH"}
        _ -> {:error, inspect(e)}
      end
  end
end
