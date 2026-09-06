defmodule Lux.RustTest do
  @moduledoc """
  Integration module for running Rust tests from Elixir.
  
  This module provides functions to:
  - Run Rust tests via `mix test` integration
  - Generate coverage reports
  - Parse and display test results
  
  ## Usage
  
  From the lux directory, run:
  
      mix rust.test
      
  Or run with coverage:
  
      mix rust.test --coverage
  """
  
  @rust_dir Application.compile_env(:lux, :rust_dir, "priv/python/rust")
  
  @doc """
  Run Rust tests and return results.
  """
  @spec run_rust_tests(keyword()) :: {:ok, map()} | {:error, String.t()}
  def run_rust_tests(opts \\ []) do
    with {:ok, cargo_path} <- find_cargo(),
         {:ok, _} <- cargo_build(cargo_path) do
      run_tests_impl(cargo_path, opts)
    end
  end
  
  defp find_cargo do
    case System.find_executable("cargo") do
      nil -> {:error, "Cargo not found. Please install Rust."}
      path -> {:ok, path}
    end
  end
  
  defp cargo_build(cargo_path) do
    rust_dir = Path.expand(@rust_dir)
    
    if File.exists?(Path.join(rust_dir, "Cargo.toml")) do
      {output, exit_code} = System.cmd(cargo_path, ["build", "--tests"], cd: rust_dir)
      
      if exit_code == 0 do
        {:ok, output}
      else
        {:error, "Cargo build failed: #{output}"}
      end
    else
      {:error, "Rust directory not found: #{rust_dir}"}
    end
  end
  
  defp run_tests_impl(cargo_path, opts) do
    rust_dir = Path.expand(@rust_dir)
    args = if opts[:coverage], do: ["test", "--", "--nocapture", "--coverage"], else: ["test"]
    
    {output, exit_code} = System.cmd(cargo_path, args, cd: rust_dir)
    
    results = parse_test_output(output)
    
    %{
      exit_code: exit_code,
      output: output,
      results: results,
      passed: results |> Enum.filter(& &1.passed) |> length,
      failed: results |> Enum.filter(&(not &1.passed)) |> length
    }
    |> then(&{:ok, &1})
  end
  
  @doc """
  Parse Rust test output into structured results.
  """
  @spec parse_test_output(String.t()) :: [map()]
  def parse_test_output(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "test "))
    |> Enum.map(&parse_test_line/1)
    |> Enum.reject(&is_nil/1)
  end
  
  defp parse_test_line(line) do
    with [_, name, status, duration] <- Regex.run(~r/test (.+?) \.\.\. (ok|FAILED) \(([\d.]+)s\)/, line) do
      %{
        name: name,
        passed: status == "ok",
        duration_ms: Float.parse(duration) |> elem(0) |> Kernel.*(1000) |> round
      }
    end
  end
  
  @doc """
  Generate coverage report for Rust tests.
  """
  @spec coverage_report(keyword()) :: {:ok, map()} | {:error, String.t()}
  def coverage_report(opts \\ []) do
    with {:ok, cargo_path} <- find_cargo(),
         {:ok, _} <- cargo_build(cargo_path) do
      rust_dir = Path.expand(@rust_dir)
      
      {output, exit_code} = System.cmd(
        cargo_path,
        ["test", "--", "--nocapture", "--coverage"],
        cd: rust_dir,
        stderr_to_stdout: true
      )
      
      if exit_code == 0 do
        {:ok, %{output: output, generated_at: DateTime.utc_now()}}
      else
        {:error, "Coverage run failed"}
      end
    end
  end
end
