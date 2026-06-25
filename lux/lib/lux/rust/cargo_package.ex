defmodule Lux.Rust.CargoPackage do
  @moduledoc """
  Cargo Package Management Integration for Lux ($300).

  Provides helpers for managing Rust/Cargo dependencies,
  parsing Cargo.toml manifests, and running cargo commands
  from within Elixir for NIF builds and workspace management.

  ## Configuration

      config :lux, Lux.Rust.CargoPackage,
        workspace_root: System.get_env("CARGO_WORKSPACE_ROOT") || File.cwd!()
  """

  require Logger

  def workspace_root do
    Application.get_env(:lux, __MODULE__, [])[:workspace_root] ||
      System.get_env("CARGO_WORKSPACE_ROOT") ||
      File.cwd!()
  end

  @doc "Runs a cargo command in the workspace and returns {exit_code, output}."
  @spec run(String.t(), list(), keyword()) :: {:ok, String.t()} | {:error, {integer(), String.t()}}
  def run(subcmd, args \\ [], opts \\ []) do
    cwd = Keyword.get(opts, :cwd, workspace_root())
    cmd_args = [subcmd | args]
    Logger.debug("cargo #{Enum.join(cmd_args, " ")} (cwd: #{cwd})")
    case System.cmd("cargo", cmd_args, cd: cwd, stderr_to_stdout: true) do
      {output, 0}   -> {:ok, output}
      {output, code} -> {:error, {code, output}}
    end
  end

  @doc "Parses a Cargo.toml file and returns it as a map."
  @spec parse_manifest(Path.t()) :: {:ok, map()} | {:error, term()}
  def parse_manifest(path) do
    with {:ok, content} <- File.read(path),
         {:ok, parsed}  <- Toml.decode(content) do
      {:ok, parsed}
    end
  end

  @doc "Lists all workspace member crate paths."
  @spec workspace_members(Path.t()) :: {:ok, list(String.t())} | {:error, term()}
  def workspace_members(manifest_path \\ nil) do
    path = manifest_path || Path.join(workspace_root(), "Cargo.toml")
    with {:ok, manifest} <- parse_manifest(path) do
      members = get_in(manifest, ["workspace", "members"]) || []
      {:ok, members}
    end
  end

  @doc "Checks for outdated dependencies via cargo outdated."
  @spec check_outdated(keyword()) :: {:ok, String.t()} | {:error, term()}
  def check_outdated(opts \\ []) do
    run("outdated", ["--format", "json"], opts)
  end

  @doc "Builds the workspace in release mode."
  @spec build_release(keyword()) :: {:ok, String.t()} | {:error, {integer(), String.t()}}
  def build_release(opts \\ []) do
    run("build", ["--release"], opts)
  end

  @doc "Runs the full test suite."
  @spec test(keyword()) :: {:ok, String.t()} | {:error, {integer(), String.t()}}
  def test(opts \\ []) do
    run("test", [], opts)
  end
end
