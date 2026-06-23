defmodule Lux.Cargo do
  @moduledoc """
  Cargo package management integration for Lux.

  This module provides functions for managing Rust/Cargo dependencies, resolving
  packages, building Rust projects, and caching downloaded crate artifacts.

  ## Usage

      # Generate a new Cargo.toml
      Lux.Cargo.init("my_project")

      # Add a dependency
      Lux.Cargo.add_dependency("path/to/Cargo.toml", "serde", "1.0")

      # Resolve and validate dependencies
      Lux.Cargo.resolve_dependencies("path/to/Cargo.toml")

      # Build project
      Lux.Cargo.build("path/to/project")

  """

  require Logger

  @default_edition "2021"
  @default_version "0.1.0"
  @cache_dir Path.join(System.tmp_dir!(), "lux_cargo_cache")

  # ---------------------------------------------------------------------------
  # Cargo.toml Management
  # ---------------------------------------------------------------------------

  @doc """
  Generates a new Cargo.toml with the given package name and optional
  list of `{name, version}` dependencies.

  ## Examples

      iex> Lux.Cargo.generate_toml("my_crate", [{"serde", "1.0"}, {"tokio", "1"}])
      "[package]\\nname = \\"my_crate\\"\\n..."

  """
  @spec generate_toml(String.t(), [{String.t(), String.t()}]) :: String.t()
  def generate_toml(package_name, dependencies \\ []) do
    deps_section =
      Enum.map_join(dependencies, "\n", fn {name, ver} ->
        ~s(#{name} = "#{ver}")
      end)

    """
    [package]
    name = "#{package_name}"
    version = "#{@default_version}"
    edition = "#{@default_edition}"

    [dependencies]
    #{deps_section}
    """
  end

  @doc """
  Parses the content of a Cargo.toml string into a structured map with
  `:name`, `:version`, `:edition`, and `:dependencies` keys.

  ## Examples

      iex> Lux.Cargo.parse_toml("[package]\\nname = \\"foo\\"\\nversion = \\"0.1.0\\"")
      {:ok, %{name: "foo", version: "0.1.0", edition: "2021", dependencies: %{}}}

  """
  @spec parse_toml(String.t()) :: {:ok, map()} | {:error, String.t()}
  def parse_toml(content) when is_binary(content) do
    name = extract_toml_value(content, "name") || ""
    version = extract_toml_value(content, "version") || @default_version
    edition = extract_toml_value(content, "edition") || @default_edition

    deps =
      case Regex.run(~r/\[dependencies\]\n(.*?)(\n\[|\z)/s, content) do
        [_, deps_section | _] ->
          deps_section
          |> String.split("\n")
          |> Enum.reject(&(String.trim(&1) == ""))
          |> Enum.reduce(%{}, fn line, acc ->
            case Regex.run(~r/^(\S+)\s*=\s*"([^"]+)"/, String.trim(line)) do
              [_, dep_name, dep_version] -> Map.put(acc, dep_name, dep_version)
              _ -> acc
            end
          end)

        _ ->
          %{}
      end

    {:ok, %{name: name, version: version, edition: edition, dependencies: deps}}
  end

  @doc """
  Reads a Cargo.toml file at `path` and returns a parsed map.
  """
  @spec read_toml(String.t()) :: {:ok, map()} | {:error, String.t()}
  def read_toml(path) do
    with {:ok, content} <- File.read(path) do
      parse_toml(content)
    else
      {:error, reason} -> {:error, "Failed to read #{path}: #{inspect(reason)}"}
    end
  end

  @doc """
  Writes a Cargo.toml file to `path` with the given package and dependencies.
  """
  @spec write_toml(String.t(), String.t(), [{String.t(), String.t()}]) ::
          {:ok, String.t()} | {:error, String.t()}
  def write_toml(path, package_name, dependencies \\ []) do
    content = generate_toml(package_name, dependencies)

    case File.write(path, content) do
      :ok -> {:ok, content}
      {:error, reason} -> {:error, "Failed to write #{path}: #{inspect(reason)}"}
    end
  end

  @doc """
  Adds a dependency to an existing Cargo.toml at `path`.
  """
  @spec add_dependency(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def add_dependency(path, package_name, version) do
    with {:ok, parsed} <- read_toml(path) do
      updated_deps =
        Map.put(parsed.dependencies, package_name, version)
        |> Enum.map(fn {k, v} -> {k, v} end)

      write_toml(path, parsed.name, updated_deps)
    end
  end

  @doc """
  Removes a dependency from an existing Cargo.toml at `path`.
  """
  @spec remove_dependency(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def remove_dependency(path, package_name) do
    with {:ok, parsed} <- read_toml(path) do
      updated_deps =
        Map.delete(parsed.dependencies, package_name)
        |> Enum.map(fn {k, v} -> {k, v} end)

      write_toml(path, parsed.name, updated_deps)
    end
  end

  @doc """
  Updates a dependency version in an existing Cargo.toml at `path`.
  """
  @spec update_dependency(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def update_dependency(path, package_name, new_version) do
    add_dependency(path, package_name, new_version)
  end

  # ---------------------------------------------------------------------------
  # Dependency Resolution
  # ---------------------------------------------------------------------------

  @doc """
  Resolves and validates the dependencies for a Cargo.toml at `path`.

  When Cargo is available, runs `cargo fetch` to download and lock dependencies.
  Returns the list of resolved dependency names and versions.
  """
  @spec resolve_dependencies(String.t()) :: {:ok, [map()]} | {:error, String.t()}
  def resolve_dependencies(path) do
    dir = Path.dirname(path)

    case cargo_available?() do
      true ->
        case cargo_cmd(["fetch", "--manifest-path", path], dir) do
          {:ok, _output} ->
            with {:ok, parsed} <- read_toml(path) do
              deps =
                Enum.map(parsed.dependencies, fn {name, version} ->
                  %{name: name, version: version, resolved: true}
                end)

              {:ok, deps}
            end

          {:error, reason} ->
            {:error, "Dependency resolution failed: #{reason}"}
        end

      false ->
        Logger.warning("Cargo not found, resolving dependencies from Cargo.toml only")

        with {:ok, parsed} <- read_toml(path) do
          deps =
            Enum.map(parsed.dependencies, fn {name, version} ->
              %{name: name, version: version, resolved: false}
            end)

          {:ok, deps}
        end
    end
  end

  @doc """
  Searches crates.io for a crate by name.
  Returns a list of matching crate maps with `:name`, `:version`, `:description`.
  """
  @spec search_crate(String.t(), keyword()) :: {:ok, [map()]} | {:error, String.t()}
  def search_crate(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    case cargo_available?() do
      true ->
        case cargo_cmd(["search", query, "--limit", to_string(limit)], System.tmp_dir!()) do
          {:ok, output} ->
            crates =
              output
              |> String.split("\n")
              |> Enum.filter(&String.contains?(&1, "="))
              |> Enum.map(fn line ->
                case Regex.run(~r/^(\S+)\s*=\s*"([^"]+)"(.*)$/, line) do
                  [_, name, version, rest] ->
                    description = rest |> String.trim() |> String.trim_leading("#") |> String.trim()
                    %{name: name, version: version, description: description}

                  _ ->
                    nil
                end
              end)
              |> Enum.reject(&is_nil/1)

            {:ok, crates}

          {:error, reason} ->
            {:error, reason}
        end

      false ->
        {:error, "Cargo not found. Please install Rust: https://rustup.rs"}
    end
  end

  # ---------------------------------------------------------------------------
  # Build System Integration
  # ---------------------------------------------------------------------------

  @doc """
  Initialises a new Cargo project at `path`.

  ## Options

  - `:lib` — Creates a library project (default: false, creates a binary)
  - `:name` — Overrides project name

  """
  @spec init(String.t(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def init(path, opts \\ []) do
    args = if Keyword.get(opts, :lib, false), do: ["init", "--lib", path], else: ["init", path]

    case cargo_cmd(args, System.tmp_dir!()) do
      {:ok, _output} -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Builds the Cargo project at `project_dir`.

  ## Options

  - `:release` — Build in release mode (default: false)
  - `:target` — Cross-compile target triple
  - `:features` — List of Cargo features to enable

  """
  @spec build(String.t(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def build(project_dir, opts \\ []) do
    args = ["build"] ++ build_args(opts)
    env = setup_cache_env()

    case cargo_cmd(args, project_dir, 300_000, env) do
      {:ok, output} -> {:ok, output}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Runs `cargo test` in the Cargo project at `project_dir`.
  """
  @spec test(String.t(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def test(project_dir, opts \\ []) do
    args = ["test"] ++ build_args(opts)

    case cargo_cmd(args, project_dir, 300_000) do
      {:ok, output} -> {:ok, output}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Checks whether `cargo` is available in PATH.
  """
  @spec cargo_available?() :: boolean()
  def cargo_available? do
    case System.find_executable("cargo") do
      nil -> false
      _ -> true
    end
  end

  # ---------------------------------------------------------------------------
  # Package Caching
  # ---------------------------------------------------------------------------

  @doc """
  Returns the path to Lux's Cargo cache directory.
  """
  @spec cache_dir() :: String.t()
  def cache_dir, do: @cache_dir

  @doc """
  Ensures the package cache directory exists.
  """
  @spec ensure_cache() :: {:ok, String.t()} | {:error, String.t()}
  def ensure_cache do
    case File.mkdir_p(@cache_dir) do
      :ok -> {:ok, @cache_dir}
      {:error, reason} -> {:error, "Failed to create cache directory: #{inspect(reason)}"}
    end
  end

  @doc """
  Returns the size of the cache directory in bytes.
  """
  @spec cache_size() :: {:ok, non_neg_integer()} | {:error, String.t()}
  def cache_size do
    if File.dir?(@cache_dir) do
      size =
        @cache_dir
        |> Path.join("**/*")
        |> Path.wildcard()
        |> Enum.reduce(0, fn path, acc ->
          case File.stat(path) do
            {:ok, %{size: s}} -> acc + s
            _ -> acc
          end
        end)

      {:ok, size}
    else
      {:ok, 0}
    end
  end

  @doc """
  Clears all cached packages from the Lux Cargo cache.
  """
  @spec clear_cache() :: :ok | {:error, String.t()}
  def clear_cache do
    case File.rm_rf(@cache_dir) do
      {:ok, _} -> :ok
      {:error, reason, _} -> {:error, "Failed to clear cache: #{inspect(reason)}"}
    end
  end

  @doc """
  Sets up the CARGO_HOME environment variable pointing to the Lux cache.
  Returns a map of env vars suitable for passing to `System.cmd/3`.
  """
  @spec setup_cache_env() :: map()
  def setup_cache_env do
    cargo_home = Path.join(@cache_dir, "cargo_home")
    File.mkdir_p!(cargo_home)
    %{"CARGO_HOME" => cargo_home}
  end

  # ---------------------------------------------------------------------------
  # Version Management
  # ---------------------------------------------------------------------------

  @doc """
  Returns the currently installed Cargo version string.
  """
  @spec cargo_version() :: {:ok, String.t()} | {:error, String.t()}
  def cargo_version do
    case cargo_cmd(["--version"], System.tmp_dir!()) do
      {:ok, output} -> {:ok, String.trim(output)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns the currently installed Rustc version string.
  """
  @spec rustc_version() :: {:ok, String.t()} | {:error, String.t()}
  def rustc_version do
    case cmd("rustc", ["--version"]) do
      {:ok, output} -> {:ok, String.trim(output)}
      {:error, reason} -> {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp cargo_cmd(args, cwd, timeout \\ 120_000, extra_env \\ %{}) do
    env = Map.merge(setup_cache_env(), extra_env)
    env_list =
      Enum.map(env, fn {k, v} ->
        {String.to_charlist(to_string(k)), String.to_charlist(to_string(v))}
      end)

    try do
      case System.cmd("cargo", args,
             cd: cwd,
             stderr_to_stdout: true,
             env: env_list,
             timeout: timeout
           ) do
        {output, 0} -> {:ok, output}
        {output, code} -> {:error, "Cargo command failed (exit #{code}): #{output}"}
      end
    rescue
      e in ErlangError ->
        case e do
          %ErlangError{original: :enoent} ->
            {:error, "Cargo not found. Please install Rust: https://rustup.rs"}

          _ ->
            {:error, "Cargo command error: #{Exception.message(e)}"}
        end
    end
  end

  defp cmd(command, args) do
    try do
      case System.cmd(command, args, stderr_to_stdout: true) do
        {output, 0} -> {:ok, output}
        {output, code} -> {:error, "Command '#{command}' failed (exit #{code}): #{output}"}
      end
    rescue
      e in ErlangError ->
        {:error, "#{command} not found: #{Exception.message(e)}"}
    end
  end

  defp build_args(opts) do
    args = []
    args = if Keyword.get(opts, :release, false), do: args ++ ["--release"], else: args

    args =
      case Keyword.get(opts, :target) do
        nil -> args
        target -> args ++ ["--target", target]
      end

    case Keyword.get(opts, :features) do
      nil -> args
      [] -> args
      features -> args ++ ["--features", Enum.join(features, ",")]
    end
  end

  defp extract_toml_value(content, key) do
    case Regex.run(~r/#{Regex.escape(key)}\s*=\s*"([^"]+)"/, content) do
      [_, value] -> value
      _ -> nil
    end
  end
end
