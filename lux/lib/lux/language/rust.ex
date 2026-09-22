defmodule Lux.Language.Rust do
  @moduledoc """
  Integration helpers for managing Rust (Cargo) based projects inside Lux.

  This module provides:

  * Generation of a minimal `Cargo.toml` file.
  * Parsing of an existing `Cargo.toml` into a map.
  * Dependency resolution using `cargo metadata`.
  * Build pipeline integration via `cargo build`.
  * Simple version handling utilities.
  * A very small package cache to avoid rebuilding unchanged crates.

  The implementation purposefully stays lightweight and relies on the
  system `cargo` binary being available in the execution environment.
  """

  @cargo_bin "cargo"
  @default_cache_dir Path.join([System.tmp_dir!(), "lux_rust_cache"])

  @doc """
  Generates a `Cargo.toml` string for a library crate.

  ## Parameters

    * `name` – the crate name (must be a valid Cargo identifier)
    * `deps` – a list of `{crate_name, version}` tuples, e.g. `[{"serde", "1.0"}]`

  ## Example

      iex> Lux.Language.Rust.generate_cargo_toml("my_lib", [{"serde", "1.0"}])
      "[package]\\nname = \\"my_lib\\"\\nversion = \\"0.1.0\\"\\nedition = \\"2021\\"\\n\\n[dependencies]\\nserde = \\"1.0\\"\\n"
  """
  @spec generate_cargo_toml(String.t(), [{String.t(), String.t()}]) :: String.t()
  def generate_cargo_toml(name, deps \\ []) when is_binary(name) and is_list(deps) do
    deps_section =
      deps
      |> Enum.map(fn {crate, ver} -> ~s(#{crate} = "#{ver}") end)
      |> Enum.join("\n")

    """
    [package]
    name = "#{name}"
    version = "0.1.0"
    edition = "2021"

    [dependencies]
    #{deps_section}
    """
    |> String.trim()
  end

  @doc """
  Parses a `Cargo.toml` file into a map with `:package` and `:dependencies` keys.

  It uses the `toml` library (which is a runtime dependency of Lux). If the file
  cannot be parsed, `{:error, reason}` is returned.

  ## Example

      iex> {:ok, data} = Lux.Language.Rust.parse_cargo_toml("path/to/Cargo.toml")
      iex> data.package.name
      "my_lib"
  """
  @spec parse_cargo_toml(String.t()) :: {:ok, map()} | {:error, any()}
  def parse_cargo_toml(path) when is_binary(path) do
    case File.read(path) do
      {:ok, content} ->
        case Toml.decode(content) do
          {:ok, map} -> {:ok, map}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Resolves the full dependency graph of a Cargo project using `cargo metadata`.

  Returns `{:ok, packages}` where `packages` is a list of maps containing at
  least `name` and `version`. On failure returns `{:error, reason}`.

  ## Example

      iex> {:ok, pkgs} = Lux.Language.Rust.resolve_dependencies("/my/project")
  """
  @spec resolve_dependencies(String.t()) :: {:ok, list(map())} | {:error, any()}
  def resolve_dependencies(project_dir) when is_binary(project_dir) do
    opts = [cd: project_dir, stderr_to_stdout: true]

    case System.cmd(@cargo_bin, ["metadata", "--format-version", "1", "--no-deps"], opts) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, %{"packages" => packages}} -> {:ok, packages}
          error -> {:error, error}
        end

      {output, code} ->
        {:error, %{exit_code: code, message: output}}
    end
  end

  @doc """
  Builds the Cargo project located at `project_dir` using `cargo build --release`.

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @spec build_project(String.t()) :: :ok | {:error, any()}
  def build_project(project_dir) when is_binary(project_dir) do
    opts = [cd: project_dir, stderr_to_stdout: true]

    case System.cmd(@cargo_bin, ["build", "--release"], opts) do
      {_output, 0} -> :ok
      {output, code} -> {:error, %{exit_code: code, message: output}}
    end
  end

  @doc """
  Returns the path to the cache directory used for compiled Rust artifacts.
  The directory is created on first use.
  """
  @spec cache_dir() :: String.t()
  def cache_dir do
    unless File.dir?(@default_cache_dir) do
      File.mkdir_p!(@default_cache_dir)
    end

    @default_cache_dir
  end

  @doc """
  Caches the compiled `target/release` directory of a Cargo project.

  The function copies the compiled artifacts into the global cache directory,
  namespaced by the project name and version (derived from `Cargo.toml`).

  Returns `:ok` on success or `{:error, reason}`.
  """
  @spec cache_package(String.t()) :: :ok | {:error, any()}
  def cache_package(project_dir) when is_binary(project_dir) do
    with {:ok, toml} <- parse_cargo_toml(Path.join(project_dir, "Cargo.toml")),
         %{"package" => %{"name" => name, "version" => version}} <- toml,
         src = Path.join([project_dir, "target", "release"]),
         true <- File.dir?(src) do
      dest = Path.join([cache_dir(), "#{name}-#{version}"])
      case File.cp_r(src, dest) do
        {:ok, _} -> :ok
        {:error, reason, _file} -> {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_cargo_toml}
    end
  end

  @doc """
  Retrieves a cached package if it exists.

  Returns `{:ok, path}` where `path` points to the cached `release` directory,
  or `:error` if the cache miss occurs.
  """
  @spec fetch_cached(String.t(), String.t()) :: {:ok, String.t()} | :error
  def fetch_cached(name, version) when is_binary(name) and is_binary(version) do
    path = Path.join([cache_dir(), "#{name}-#{version}"])

    if File.dir?(path) do
      {:ok, path}
    else
      :error
    end
  end
end
