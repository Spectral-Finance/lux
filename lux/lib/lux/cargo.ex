defmodule Lux.Cargo do
  @moduledoc """
  Provides Cargo (Rust) package management integration for Lux.

  This module implements the package-management side of the upcoming Rust
  language integration described in the language support guide. It can:

  - Parse and generate `Cargo.toml` manifests
  - Add, remove and resolve dependencies (with version management)
  - Drive the Rust build pipeline through the `cargo` CLI (build, test, run, version)
  - Cache resolved packages to avoid re-fetching from the registry

  All functions that shell out to `cargo` return `{:ok, term()}` on success or
  `{:error, String.t()}` on failure. Functions that only manipulate manifests in memory
  (parsing/generation) are pure and do not require a Rust toolchain.
  """

  @type version :: String.t()

  @type manifest :: %{
          package: %{name: String.t(), version: String.t(), edition: String.t()},
          dependencies: %{optional(String.t()) => version()}
        }

  @type run_option ::
          {:cwd, String.t()}
          | {:release, boolean()}

  @type run_options :: [run_option()]

  @default_edition "2021"

  # ---------------------------------------------------------------------------
  # Manifest management (pure)
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new in-memory `Cargo.toml` manifest for the given package.
  """
  @spec new_manifest(String.t(), version(), keyword()) :: manifest()
  def new_manifest(name, version, opts \\ [])
      when is_binary(name) and is_binary(version) do
    edition = Keyword.get(opts, :edition, @default_edition)

    %{
      package: %{name: name, version: version, edition: edition},
      dependencies: %{}
    }
  end

  @doc """
  Adds (or updates) a dependency with a version requirement in the manifest.
  """
  @spec add_dependency(manifest(), String.t(), version()) :: manifest()
  def add_dependency(%{dependencies: deps} = manifest, name, version)
      when is_binary(name) and is_binary(version) do
    %{manifest | dependencies: Map.put(deps, name, version)}
  end

  @doc """
  Removes a dependency from the manifest.
  """
  @spec remove_dependency(manifest(), String.t()) :: manifest()
  def remove_dependency(%{dependencies: deps} = manifest, name) when is_binary(name) do
    %{manifest | dependencies: Map.delete(deps, name)}
  end

  @doc """
  Returns the version requirement for a dependency, or `nil` if absent.
  """
  @spec get_dependency(manifest(), String.t()) :: version() | nil
  def get_dependency(%{dependencies: deps}, name) when is_binary(name) do
    Map.get(deps, name)
  end

  @doc """
  Renders a manifest into `Cargo.toml` text.
  """
  @spec to_toml(manifest()) :: String.t()
  def to_toml(manifest) do
    case Lux.Cargo.Toml.encode(manifest) do
      {:ok, toml} -> toml
      {:error, _} -> ""
    end
  end

  @doc """
  Parses `Cargo.toml` text into a manifest map.
  """
  @spec from_toml(String.t()) :: {:ok, manifest()} | {:error, String.t()}
  def from_toml(toml) when is_binary(toml) do
    case Lux.Cargo.Toml.decode(toml) do
      {:ok, decoded} ->
        package = Map.get(decoded, "package", %{})
        deps = Map.get(decoded, "dependencies", %{})

        case package do
          %{"name" => name, "version" => version} ->
            {:ok,
             %{
               package: %{
                 name: name,
                 version: version,
                 edition: Map.get(package, "edition", @default_edition)
               },
               dependencies: deps
             }}

          _incomplete ->
            {:error, "invalid Cargo.toml: missing package name or version"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # File helpers
  # ---------------------------------------------------------------------------

  @doc """
  Writes a manifest to a `Cargo.toml` file at the given path.
  """
  @spec write_manifest(manifest(), Path.t()) :: :ok | {:error, String.t()}
  def write_manifest(manifest, path) when is_binary(path) do
    case File.write(path, to_toml(manifest)) do
      :ok -> :ok
      {:error, reason} -> {:error, "failed to write #{path}: #{:file.format_error(reason)}"}
    end
  end

  @doc """
  Reads and parses a `Cargo.toml` file from the given path.
  """
  @spec read_manifest(Path.t()) :: {:ok, manifest()} | {:error, String.t()}
  def read_manifest(path) when is_binary(path) do
    case File.read(path) do
      {:ok, contents} -> from_toml(contents)
      {:error, reason} -> {:error, "failed to read #{path}: #{:file.format_error(reason)}"}
    end
  end

  # ---------------------------------------------------------------------------
  # Build pipeline / dependency resolution (cargo CLI)
  # ---------------------------------------------------------------------------

  @doc """
  Resolves dependencies for a Rust project by running `cargo fetch`.
  """
  @spec resolve(run_options()) :: {:ok, String.t()} | {:error, String.t()}
  def resolve(opts \\ []) do
    run_cargo(["fetch"], opts)
  end

  @doc """
  Builds a Rust project by running `cargo build`.
  """
  @spec build(run_options()) :: {:ok, String.t()} | {:error, String.t()}
  def build(opts \\ []) do
    args = if Keyword.get(opts, :release, false), do: ["build", "--release"], else: ["build"]
    run_cargo(args, opts)
  end

  @doc """
  Runs a Rust unit test suite by running `cargo test`.
  """
  @spec test(run_options()) :: {:ok, String.t()} | {:error, String.t()}
  def test(opts \\ []) do
    run_cargo(["test"], opts)
  end

  @doc """
  Runs a Rust binary by running `cargo run`.
  """
  @spec run(String.t(), run_options()) :: {:ok, String.t()} | {:error, String.t()}
  def run(binary_name, opts \\ []) when is_binary(binary_name) do
    run_cargo(["run", "--bin", binary_name], opts)
  end

  @doc """
  Returns the installed `cargo` version, or an error if it is not available.
  """
  @spec version() :: {:ok, String.t()} | {:error, String.t()}
  def version do
    case cargo_executable() do
      nil -> {:error, "cargo executable not found on path"}
      path ->
        case System.cmd(path, ["--version"]) do
          {out, 0} -> {:ok, String.trim(out)}
          {out, code} -> {:error, "cargo version returned non-zero code #{code}: #{String.trim(out)}"}
        end
    end
  end

  defp cargo_executable do
    Application.get_env(:lux, :cargo_bin, System.find_executable("cargo"))
  end

  defp run_cargo(args, opts) do
    cwd = Keyword.get(opts, :cwd, File.cwd!())

    case cargo_executable() do
      nil ->
        {:error, "cargo executable not found"}

      path ->
        case System.cmd(path, args, cd: cwd, stderr_to_stdout: true) do
          {output, 0} -> {:ok, output}
          {output, code} -> {:error, "cargo exited with #{code}: #{String.trim(output)}"}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Package caching
  # ---------------------------------------------------------------------------

  @doc """
  Returns the directory used to cache resolved packages.
  """
  @spec cache_dir() :: String.t()
  def cache_dir do
    Application.get_env(:lux, :cargo_cache_dir, Application.app_dir(:lux, "priv/cargo_cache"))
  end

  @doc """
  Caches the resolved version of a package.
  """
  @spec cache_package(String.t(), version()) :: :ok | {:error, String.t()}
  def cache_package(name, version) when is_binary(name) and is_binary(version) do
    Lux.Cargo.Cache.put(name, version)
  end

  @doc """
  Returns the cached version for a package, or `nil` if it is not cached.
  """
  @spec cached_package(String.t()) :: version() | nil
  def cached_package(name) when is_binary(name) do
    case Lux.Cargo.Cache.get(name) do
      {:ok, version} -> version
      _miss -> nil
    end
  end

  @doc """
  Removes the entire package cache directory.
  """
  @spec clear_cache() :: :ok | {:error, String.t()}
  def clear_cache do
    case Lux.Cargo.Cache.clear() do
      :ok -> :ok
      err -> err
    end
  end
end
