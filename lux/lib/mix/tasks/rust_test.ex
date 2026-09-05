defmodule Mix.Tasks.Rust.Test do
  @moduledoc """
  Run Rust tests from Mix.
  
  Usage:
  
      mix rust.test
      mix rust.test --coverage
  
  This task:
  1. Builds the Rust project with cargo
  2. Runs the test binary
  3. Parses and displays results
  4. Integrates with ExUnit for unified reporting
  """
  use Mix.Task
  
  @shortdoc "Run Rust tests"
  
  @impl true
  def run(args) do
    IO.puts("Building Rust tests...")
    
    coverage? = "--coverage" in args || "-c" in args
    
    case Lux.RustTest.run_rust_tests(coverage: coverage?) do
      {:ok, results} ->
        display_results(results)
        System.halt(if results.exit_code == 0, do: 0, else: 1)
        
      {:error, message} ->
        Mix.shell().error(message)
        System.halt(1)
    end
  end
  
  defp display_results(results) do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("Lux Rust Test Results")
    IO.puts(String.duplicate("=", 60))
    IO.puts("Passed: #{results.passed}")
    IO.puts("Failed: #{results.failed}")
    IO.puts(String.duplicate("=", 60))
    
    if results.failed > 0 do
      IO.puts("\nFailed tests:")
      results.results
      |> Enum.filter(&(not &1.passed))
      |> Enum.each(&IO.puts("  ✗ #{&1.name}"))
    end
  end
end
