defmodule Lux.Rust do
  @moduledoc """
  Rust language support helpers for Lux.

  This module is the public facade for the Rust test integration. It keeps the
  Elixir side deterministic: callers can build a cargo test plan, run it when a
  Rust toolchain is present, parse cargo output, and create fixtures shared by
  Elixir and Rust tests.
  """

  alias Lux.Rust.Fixtures
  alias Lux.Rust.TestRunner

  @default_relative_path Path.join(["priv", "rust"])

  @doc """
  Returns the configured Rust project path.

  Set `config :lux, :rust_project_path, "/path/to/rust/crate"` to override the
  default `priv/rust` crate.
  """
  @spec project_path() :: String.t()
  def project_path do
    Application.get_env(:lux, :rust_project_path) ||
      Path.expand(@default_relative_path, File.cwd!())
  end

  @doc """
  Returns true when `cargo` is available on PATH.
  """
  @spec cargo_available?() :: boolean()
  def cargo_available?, do: not is_nil(System.find_executable("cargo"))

  @doc """
  Builds a cargo test command plan without executing it.
  """
  @spec build_test_plan(Path.t(), keyword()) :: map()
  def build_test_plan(project_root \\ project_path(), opts \\ []) do
    TestRunner.build_test_plan(project_root, opts)
  end

  @doc """
  Runs Rust tests through cargo.
  """
  @spec run_tests(Path.t(), keyword()) :: {:ok, map()} | {:error, map()}
  def run_tests(project_root \\ project_path(), opts \\ []) do
    TestRunner.run(project_root, opts)
  end

  @doc """
  Parses cargo test output into a Lux summary.
  """
  @spec parse_test_output(String.t()) :: map()
  defdelegate parse_test_output(output), to: TestRunner

  @doc """
  Parses an LCOV report into line and branch coverage totals.
  """
  @spec parse_lcov(String.t()) :: map()
  defdelegate parse_lcov(content), to: TestRunner

  @doc """
  Builds a deterministic fixture manifest for files shared with Rust tests.
  """
  @spec fixture_manifest(map() | keyword(), keyword()) :: map()
  defdelegate fixture_manifest(fixtures, opts \\ []), to: Fixtures, as: :manifest

  @doc """
  Writes fixture files into a root directory after validating relative paths.
  """
  @spec write_fixtures!(Path.t(), map() | keyword()) :: [String.t()]
  defdelegate write_fixtures!(root, fixtures), to: Fixtures, as: :write_files!
end
