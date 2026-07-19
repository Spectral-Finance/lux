defmodule Lux.Cargo do
  @moduledoc """
  Provides Cargo (Rust) package management integration for Lux.

  This module implements the package-management side of the upcoming Rust
  language integration described in the language support guide. It can:

  - Parse and generate `Cargo.toml` manifests
  - Add, remove and resolve dependencies (with version management)
  - Drive the Rust build pipeline through the `cargo` CLI
  - Cache resolved packages to avoid re-fetching from the registry

  All functions that shell out to `cargo` return `{:ok, term()}` on success or
  `{:error, String.t()}` on failure, mirroring the `Lux.Python` and
  `Lux.NodeJS` conventions. Functions that only manipulate manifests in memory
  (parsing/generation) are pure and do not require a Rust toolchain.

  ## Examples

      iex> manifest = Lux.Cargo.new_manifest("my_agent", "0.1.0")
      iex> manifest = Lux.Cargo.add_dependency(manifest, "serde", "1.0")
      iex> Lux.Cargo.get_dependency(manifest, "serde")
      "1.0"
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
  @cache_dir Path.join([System.tmp_dir!(), "lux", "cargo-cache"])

  # ---------------------------------------------------------------------------
  # Manifest management (pure)
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new in-memory `Cargo.toml` manifest for the given package.

  ## Options

    * `:edition` - The Rust edition to target (default: `"#{@default_edition}"`)

  ## Examples

      iex> Lux.Cargo.new_manifest("my_agent", "0.1.0")
      %{
        package: %{name: "my_agent", version: "0.1.0", edition: "2021"},
        dependencies: %{}
      }
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

  ## Examples

      iex> manifest = Lux.Cargo.new_manifest("app", "0.1.0")
      iex> manifest = Lux.Cargo.add_dependency(manifest, "serde", "1.0")
      iex> manifest.dependencies
      %{"serde" => "1.0"}
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

  ## Examples

      iex> manifest = Lux.Cargo.new_manifest("app", "0.1.0")
      iex> manifest = Lux.Cargo.add_dependency(manifest, "serde", "1.0")
      iex> Lux.Cargo.to_toml(manifest)
      "[package]\\nname = \\"app\\"\\nversion = \\"0.1.0\\"\\nedition = \\"2021\\"\\n\\n[dependencies]\\nserde = \\"1.0\\"\\n"
  """
  @spec to_toml(manifest()) :: String.t()
  def to_toml(%{package: package, dependencies: deps}) do
    package_section = [
      "[package]",
      ~s(name = "#{package.name}"),
      ~s(version = "#{package.version}"),
      ~s(edition = "#{package.edition}")
    ]

    deps_section =
      deps
      |> Enum.sort_by(fn {name, _version} -> name end)
      |> Enum.map(fn {name, version} -> ~s(#{name} = "#{version}") end)

    (package_section ++ ["", "[dependencies]" | deps_section])
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  @doc """
  Parses `Cargo.toml` text into a manifest map.

  Only the `[package]` and `[dependencies]` sections are interpreted; unknown
  sections are ignored. Returns `{:error, reason}` when the `[package]` name or
  version cannot be found.

  ## Examples

      iex> toml = "[package]\\nname = \\"app\\"\\nversion = \\"0.1.0\\"\\n"
      iex> {:ok, manifest} = Lux.Cargo.from_toml(toml)
      iex> manifest.package.name
      "app"
  """
  @spec from_toml(String.t()) :: {:ok, manifest()} | {:error, String.t()}
  def from_toml(toml) when is_binary(toml) do
    {package, deps, _section} =
      toml
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reduce({%{}, %{}, nil}, &parse_line/2)

    case package do
      %{name: name, version: version} ->
        {:ok,
         %{
           package: %{
             name: name,
             version: version,
             edition: Map.get(package, :edition, @default_edition)
           },
           dependencies: deps
         }}

      _incomplete ->
        {:error, "invalid Cargo.toml: missing package name or version"}
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

  Requires the `cargo` executable to be available on the host.

  ## Options

    * `:cwd` - Directory containing `Cargo.toml` (default: current directory)
  """
  @spec resolve(run_options()) :: {:ok, String.t()} | {:error, String.t()}
  def resolve(opts \\ []) do
    run_cargo(["fetch"], opts)
  end

  @doc """
  Builds a Rust project by running `cargo build`.

  ## Options

    * `:cwd` - Directory containing `Cargo.toml` (default: current directory)
    * `:release` - Build with the `--release` profile (default: `false`)
  """
  @spec build(run_options()) :: {:ok, String.t()} | {:error, String.t()}
  def build(opts \\ []) do
    args = if Keyword.get(opts, :release, false), do: ["build", "--release"], else: ["build"]
    run_cargo(args, opts)
  end

  @doc """
  Returns the installed `cargo` version, or an error if it is not available.
  """
  @spec version() :: {:ok, String.t()} | {:error, String.t()}
  def version do
    case run_cargo(["--version"], []) do
      {:ok, output} -> {:ok, String.trim(output)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp run_cargo(args, opts) do
    cwd = Keyword.get(opts, :cwd, File.cwd!())

    if System.find_executable("cargo") do
      case System.cmd("cargo", args, cd: cwd, stderr_to_stdout: true) do
        {output, 0} -> {:ok, output}
        {output, code} -> {:error, "cargo exited with #{code}: #{String.trim(output)}"}
      end
    else
      {:error, "cargo executable not found on host"}
    end
  end

  # ---------------------------------------------------------------------------
  # Package caching
  # ---------------------------------------------------------------------------

  @doc """
  Returns the directory used to cache resolved packages.
  """
  @spec cache_dir() :: String.t()
  def cache_dir, do: @cache_dir

  @doc """
  Caches the resolved version of a package under `cache_dir/0`.

  Stores the version requirement keyed by package name so subsequent
  resolutions can reuse a previously resolved version.
  """
  @spec cache_package(String.t(), version()) :: :ok | {:error, String.t()}
  def cache_package(name, version) when is_binary(name) and is_binary(version) do
    with :ok <- File.mkdir_p(@cache_dir),
         :ok <- File.write(cache_path(name), version) do
      :ok
    else
      {:error, reason} -> {:error, "failed to cache #{name}: #{:file.format_error(reason)}"}
    end
  end

  @doc """
  Returns the cached version for a package, or `nil` if it is not cached.
  """
  @spec cached_package(String.t()) :: version() | nil
  def cached_package(name) when is_binary(name) do
    case File.read(cache_path(name)) do
      {:ok, version} -> version
      {:error, _reason} -> nil
    end
  end

  @doc """
  Removes the entire package cache directory.
  """
  @spec clear_cache() :: :ok | {:error, String.t()}
  def clear_cache do
    case File.rm_rf(@cache_dir) do
      {:ok, _files} -> :ok
      {:error, reason, _file} -> {:error, "failed to clear cache: #{:file.format_error(reason)}"}
    end
  end

  defp cache_path(name) do
    Path.join(@cache_dir, "#{name}.version")
  end

  # ---------------------------------------------------------------------------
  # Internal parsing helpers
  # ---------------------------------------------------------------------------

  defp parse_line("[package]", {package, deps, _section}), do: {package, deps, :package}
  defp parse_line("[dependencies]", {package, deps, _section}), do: {package, deps, :dependencies}
  defp parse_line("[" <> _rest, {package, deps, _section}), do: {package, deps, :other}

  defp parse_line("", acc), do: acc
  defp parse_line("#" <> _comment, acc), do: acc

  defp parse_line(line, {package, deps, :package} = acc) do
    case parse_kv(line) do
      {key, value} when key in ["name", "version", "edition"] ->
        {Map.put(package, String.to_atom(key), value), deps, :package}

      _other ->
        acc
    end
  end

  defp parse_line(line, {package, deps, :dependencies} = acc) do
    case parse_kv(line) do
      {name, version} -> {package, Map.put(deps, name, version), :dependencies}
      :error -> acc
    end
  end

  defp parse_line(_line, acc), do: acc

  defp parse_kv(line) do
    case String.split(line, "=", parts: 2) do
      [key, value] ->
        {String.trim(key), value |> String.trim() |> String.trim("\"")}

      _other ->
        :error
    end
  end
end
