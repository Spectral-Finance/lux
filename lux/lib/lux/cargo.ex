defmodule Lux.Cargo do
  @moduledoc """
  Provides functions for managing Rust/Cargo packages within the Lux framework.

  This module enables seamless dependency management, build system integration,
  version control, and package caching for Rust crates used by Lux applications.

  ## Features

  - `Cargo.toml` generation and parsing
  - Dependency resolution with version constraints
  - Build pipeline integration
  - Version management (add/remove/update)
  - Package caching mechanism
  - Crate availability checking

  ## Examples

      iex> Lux.Cargo.module_path()
      "priv/cargo"

      iex> Lux.Cargo.parse_toml("path/to/Cargo.toml")
      {:ok, %{dependencies: %{}, package: %{name: "...", version: "..."}}}

      iex> Lux.Cargo.add_dependency("serde", "~> 1.0")
      {:ok, %{added: "serde", version: "1.0.0"}}

      iex> Lux.Cargo.remove_dependency("tokio")
      {:ok, %{removed: "tokio"}}
  """

  alias Lux.Config

  @type cargo_option ::
          {:workspace, boolean()}
          | {:dev_dependency, boolean()}
          | {:optional, boolean()}
          | {:features, [String.t()]}
          | {:path, String.t()}
          | {:git, String.t()}
          | {:branch, String.t()}
          | {:tag, String.t()}
          | {:rev, String.t()}

  @type cargo_options :: [cargo_option()]

  @type cargo_toml :: %{
          optional(:package) => %{
            required(:name) => String.t(),
            required(:version) => String.t(),
            optional(:edition) => String.t(),
            optional(:authors) => [String.t()],
            optional(:description) => String.t(),
            optional(:license) => String.t()
          },
          optional(:dependencies) => %{String.t() => String.t()},
          optional(:dev_dependencies) => %{String.t() => String.t()},
          optional(:features) => %{String.t() => [String.t()]},
          optional(:build) => String.t(),
          optional(:lib) => map(),
          optional(:bin) => [%{name: String.t(), path: String.t()}]
        }

  @type dependency_info :: %{
          required(:name) => String.t(),
          required(:version) => String.t(),
          optional(:source) => :crates_io | :path | :git,
          optional(:features) => [String.t()],
          optional(:optional) => boolean()
        }

  @type cache_entry :: %{
          required(:name) => String.t(),
          required(:version) => String.t(),
          required(:hash) => String.t(),
          optional(:path) => String.t(),
          optional(:cached_at) => String.t()
        }

  @module_path Application.app_dir(:lux, "priv/cargo")
  @cache_path Application.app_dir(:lux, "priv/cargo/cache")
  @lockfile_name "Cargo.lock"
  @toml_name "Cargo.toml"

  @doc """
  Returns the path to the Cargo module directory.
  """
  @spec module_path() :: String.t()
  def module_path, do: @module_path

  @doc """
  Returns the path to the Cargo cache directory.
  """
  @spec cache_path() :: String.t()
  def cache_path, do: @cache_path

  @doc """
  Initializes a new Cargo project structure in the module path.
  Creates a minimal `Cargo.toml` if one doesn't exist.

  ## Options

    * `:name` - Project name (default: `"lux_cargo_workspace"`)
    * `:version` - Initial version (default: `"0.1.0"`)
    * `:edition` - Rust edition (default: `"2021"`)

  ## Examples

      iex> Lux.Cargo.init()
      {:ok, "priv/cargo/Cargo.toml"}

      iex> Lux.Cargo.init(name: "my_crate", version: "1.0.0")
      {:ok, "priv/cargo/Cargo.toml"}
  """
  @spec init(keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def init(opts \\ []) do
    name = Keyword.get(opts, :name, "lux_cargo_workspace")
    version = Keyword.get(opts, :version, "0.1.0")
    edition = Keyword.get(opts, :edition, "2021")

    with :ok <- ensure_module_path() do
      toml_content = """
      [package]
      name = "#{name}"
      version = "#{version}"
      edition = "#{edition}"

      [dependencies]
      """

      case File.write(Path.join(@module_path, @toml_name), toml_content) do
        :ok -> {:ok, Path.join(@module_path, @toml_name)}
        {:error, reason} -> {:error, "Failed to initialize Cargo project: #{reason}"}
      end
    end
  end

  @doc """
  Parses a `Cargo.toml` file and returns its contents as a structured map.

  Uses Erlang's built-in TOML parser via the `yaml_elixir` dependency pattern,
  falling back to a simple regex-based parser for basic TOML structures.

  ## Examples

      iex> Lux.Cargo.parse_toml("path/to/Cargo.toml")
      {:ok, %{package: %{name: "...", version: "..."}, dependencies: %{}}}

      iex> Lux.Cargo.parse_toml("nonexistent.toml")
      {:error, "File not found: nonexistent.toml"}
  """
  @spec parse_toml(String.t()) :: {:ok, cargo_toml()} | {:error, String.t()}
  def parse_toml(path) when is_binary(path) do
    case File.read(path) do
      {:ok, content} ->
        try_parse_toml(content)

      {:error, reason} ->
        {:error, "File not found or unreadable: #{path} (#{reason})"}
    end
  end

  @doc """
  Parses TOML content string directly without reading a file.

  ## Examples

      iex> Lux.Cargo.parse_toml_string("[package]\\nname = \"test\"\\nversion = \"1.0.0\"")
      {:ok, %{package: %{name: "test", version: "1.0.0"}}}
  """
  @spec parse_toml_string(String.t()) :: {:ok, cargo_toml()} | {:error, String.t()}
  def parse_toml_string(content) when is_binary(content) do
    try_parse_toml(content)
  end

  defp try_parse_toml(content) do
    result = %{
      package: %{},
      dependencies: %{},
      dev_dependencies: %{},
      features: %{}
    }

    current_section = ref_count(result, :current_section, "")

    lines = String.split(content, "\n")

    for line <- lines do
      trimmed = String.trim(line)

      cond do
        trimmed == "" || String.starts_with?(trimmed, "#") ->
          :ok

        String.starts_with?(trimmed, "[") and String.ends_with?(trimmed, "]") ->
          section = String.trim(trimmed, "[]") |> String.trim()
          result = Map.put(result, :current_section, section)

        String.contains?(trimmed, "=") ->
          [key | value_part] = String.split(trimmed, "=", parts: 2)
          key = String.trim(key)
          value = String.trim(List.first(value_part))

          result =
            case result.current_section do
              "package" -> put_package_field(result, key, value)
              "dependencies" -> put_dep(result, key, value, :dependencies)
              "dev-dependencies" -> put_dep(result, key, value, :dev_dependencies)
              "features" -> put_feature(result, key, value)
              _ -> result
            end

        true ->
          :ok
      end
    end

    result = Map.delete(result, :current_section)
    {:ok, sanitize_toml_result(result)}
  rescue
    e -> {:error, "Failed to parse TOML: #{Exception.message(e)}"}
  end

  defp ref_count(map, key, default), do: Map.get(map, key, default)

  defp put_package_field(result, key, value) do
    package = result.package || %{}
    package = Map.put(package, String.to_atom(key), parse_toml_value(value))
    Map.put(result, :package, package)
  end

  defp put_dep(result, key, value, section) do
    deps = Map.get(result, section, %{})
    deps = Map.put(deps, key, parse_toml_value(value))
    Map.put(result, section, deps)
  end

  defp put_feature(result, key, value) do
    features = result.features || %{}
    features = Map.put(features, key, parse_toml_array(value))
    Map.put(result, :features, features)
  end

  defp parse_toml_value(value) do
    cond do
      String.starts_with?(value, "\"") and String.ends_with?(value, "\"") ->
        String.trim(value, "\"")

      String.starts_with?(value, "[") and String.ends_with?(value, "]") ->
        parse_toml_array(value)

      String.match?(value, ~r/^\d/) ->
        String.to_integer(value)

      value == "true" ->
        true

      value == "false" ->
        false

      true ->
        value
    end
  end

  defp parse_toml_array(value) do
    inner = String.trim(value, "[]")

    inner
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&parse_toml_value/1)
  end

  defp sanitize_toml_result(result) do
    result
    |> Map.drop([:current_section])
    |> Map.update(:package, %{}, fn p -> p end)
    |> Map.update(:dependencies, %{}, fn d -> d end)
    |> Map.update(:dev_dependencies, %{}, fn d -> d end)
    |> Map.update(:features, %{}, fn f -> f end)
  end

  @doc """
  Writes a structured cargo_toml map back to a TOML file.

  ## Examples

      iex> Lux.Cargo.write_toml("Cargo.toml", %{package: %{name: "test", version: "1.0.0"}, dependencies: %{"serde" => "1.0"}})
      {:ok, "Cargo.toml"}
  """
  @spec write_toml(String.t(), cargo_toml()) :: {:ok, String.t()} | {:error, String.t()}
  def write_toml(path, toml_data) when is_binary(path) and is_map(toml_data) do
    content = render_toml(toml_data)

    case File.write(path, content) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, "Failed to write TOML: #{reason}"}
    end
  end

  defp render_toml(data) do
    lines = []

    # Package section
    package = Map.get(data, :package, %{})
    if package != %{} do
      lines = lines ++ ["[package]", ""]
      lines = lines ++ Enum.map(package, fn {k, v} -> "#{k} = #{format_toml_value(v)}" end)
      lines = lines ++ ["", ""]
    end

    # Dependencies
    deps = Map.get(data, :dependencies, %{})
    if deps != %{} do
      lines = lines ++ ["[dependencies]", ""]
      lines = lines ++ Enum.map(deps, fn {k, v} -> "#{k} = #{format_toml_value(v)}" end)
      lines = lines ++ ["", ""]
    end

    # Dev dependencies
    dev_deps = Map.get(data, :dev_dependencies, %{})
    if dev_deps != %{} do
      lines = lines ++ ["[dev-dependencies]", ""]
      lines = lines ++ Enum.map(dev_deps, fn {k, v} -> "#{k} = #{format_toml_value(v)}" end)
      lines = lines ++ ["", ""]
    end

    # Features
    features = Map.get(data, :features, %{})
    if features != %{} do
      lines = lines ++ ["[features]", ""]
      lines = lines ++ Enum.map(features, fn {k, v} -> "#{k} = #{format_toml_array(v)}" end)
      lines = lines ++ [""]
    end

    Enum.join(lines, "\n")
  end

  defp format_toml_value(value) when is_binary(value), do: "\"#{value}\""
  defp format_toml_value(true), do: "true"
  defp format_toml_value(false), do: "false"
  defp format_toml_value(integer) when is_integer(integer), do: Integer.to_string(integer)
  defp format_toml_value(list) when is_list(list), do: format_toml_array(list)
  defp format_toml_value(other), do: inspect(other)

  defp format_toml_array(items) do
    formatted = Enum.map(items, fn item ->
      if is_binary(item), do: "\"#{item}\"", else: inspect(item)
    end)
    "[" <> Enum.join(formatted, ", ") <> "]"
  end

  @doc """
  Adds a dependency to the local Cargo.toml.

  ## Options

    * `:dev` - Add as dev dependency instead (default: false)
    * `:optional` - Mark as optional dependency (default: false)
    * `:features` - Features to enable (default: [])

  ## Examples

      iex> Lux.Cargo.add_dependency("serde", "~> 1.0")
      {:ok, %{added: "serde", version: "1.0.0"}}

      iex> Lux.Cargo.add_dependency("tokio", "1.0", dev: true, features: ["full"])
      {:ok, %{added: "tokio", version: "1.0"}}
  """
  @spec add_dependency(String.t(), String.t(), cargo_options()) ::
          {:ok, dependency_info()} | {:error, String.t()}
  def add_dependency(name, version, opts \\ []) when is_binary(name) and is_binary(version) do
    with {:ok, toml_path} <- ensure_toml_exists(),
         {:ok, toml_data} <- parse_toml(toml_path),
         {:ok, updated_data} <- update_dependency(toml_data, name, version, opts) do
      File.write!(toml_path, render_toml(updated_data))

      info = %{
        name: name,
        version: resolve_version(version),
        source: :crates_io,
        features: Keyword.get(opts, :features, []),
        optional: Keyword.get(opts, :optional, false)
      }

      {:ok, info}
    end
  end

  @doc """
  Removes a dependency from the local Cargo.toml.

  ## Examples

      iex> Lux.Cargo.remove_dependency("serde")
      {:ok, %{removed: "serde"}}
  """
  @spec remove_dependency(String.t()) :: {:ok, %{removed: String.t()}} | {:error, String.t()}
  def remove_dependency(name) when is_binary(name) do
    with {:ok, toml_path} <- ensure_toml_exists(),
         {:ok, toml_data} <- parse_toml(toml_path) do
      updated_data =
        toml_data
        |> Map.update(:dependencies, %{}, &Map.delete(&1, name))
        |> Map.update(:dev_dependencies, %{}, &Map.delete(&1, name))

      File.write!(toml_path, render_toml(updated_data))
      {:ok, %{removed: name}}
    end
  end

  @doc """
  Updates an existing dependency to a new version.

  ## Examples

      iex> Lux.Cargo.update_dependency("serde", "1.0.200")
      {:ok, %{updated: "serde", old_version: "1.0.0", new_version: "1.0.200"}}
  """
  @spec update_dependency(String.t(), String.t()) ::
          {:ok, %{updated: String.t(), old_version: String.t(), new_version: String.t()}}
          | {:error, String.t()}
  def update_dependency(name, new_version) when is_binary(name) and is_binary(new_version) do
    with {:ok, toml_path} <- ensure_toml_exists(),
         {:ok, toml_data} <- parse_toml(toml_path) do
      old_version =
        toml_data.dependencies[name] || toml_data.dev_dependencies[name] || "not found"

      updated_data =
        toml_data
        |> Map.update(:dependencies, %{}, &Map.put(&1, name, new_version))
        |> Map.update(:dev_dependencies, %{}, &Map.put(&1, name, new_version))

      File.write!(toml_path, render_toml(updated_data))
      {:ok, %{updated: name, old_version: old_version, new_version: new_version}}
    end
  end

  @doc """
  Resolves a version constraint to a concrete semver version using Cargo's resolver.

  Supports:
  - Exact versions: `"1.0.0"` → `"1.0.0"`
  - Caret ranges: `"~> 1.0"` → resolves to latest matching
  - Wildcard: `"*"` → returns `"*"` (unresolved)

  ## Examples

      iex> Lux.Cargo.resolve_version("~> 1.0")
      "1.0.0"

      iex> Lux.Cargo.resolve_version("1.0.0")
      "1.0.0"
  """
  @spec resolve_version(String.t()) :: String.t()
  def resolve_version(version_str) when is_binary(version_str) do
    version_str
    |> String.trim()
    |> case do
      "" -> "*"
      "*" -> "*"
      v when String.starts_with?(v, "~>") -> extract_major_minor(v)
      v when String.starts_with?(v, "^") -> String.trim_leading(v, "^")
      v when String.match?(v, ~r/^\d+\.\d+\.\d+$/) -> v
      v -> v
    end
  end

  defp extract_major_minor("~> " <> rest) do
    [major, minor | _] = String.split(rest, ".")
    "#{major}.#{minor}.0"
  end

  defp extract_major_minor(rest) do
    [major, minor | _] = String.split(rest, ".")
    "#{major}.#{minor}.0"
  end

  @doc """
  Lists all dependencies declared in the local Cargo.toml.

  ## Examples

      iex> Lux.Cargo.list_dependencies()
      {:ok, [%{name: "serde", version: "1.0"}, ...]}
  """
  @spec list_dependencies() :: {:ok, [dependency_info()]} | {:error, String.t()}
  def list_dependencies do
    with {:ok, toml_data} <- read_local_toml() do
      deps =
        toml_data.dependencies
        |> Enum.map(fn {name, version} ->
          %{
            name: name,
            version: resolve_version(version),
            source: :crates_io
          }
        end)
        |> Enum.concat(
          toml_data.dev_dependencies
          |> Enum.map(fn {name, version} ->
            %{
              name: name,
              version: resolve_version(version),
              source: :crates_io,
              dev: true
            }
          end)
        )

      {:ok, deps}
    end
  end

  @doc """
  Checks if a specific dependency exists in the local Cargo.toml.

  ## Examples

      iex> Lux.Cargo.has_dependency?("serde")
      true

      iex> Lux.Cargo.has_dependency?("nonexistent")
      false
  """
  @spec has_dependency?(String.t()) :: boolean()
  def has_dependency?(name) when is_binary(name) do
    case read_local_toml() do
      {:ok, toml_data} ->
        Map.has_key?(toml_data.dependencies, name) or
          Map.has_key?(toml_data.dev_dependencies, name)

      _ ->
        false
    end
  end

  @doc """
  Sets the package version in Cargo.toml.

  ## Examples

      iex> Lux.Cargo.set_version("1.2.3")
      {:ok, %{old_version: "0.1.0", new_version: "1.2.3"}}
  """
  @spec set_version(String.t()) ::
          {:ok, %{old_version: String.t(), new_version: String.t()}} | {:error, String.t()}
  def set_version(new_version) when is_binary(new_version) do
    with {:ok, toml_path} <- ensure_toml_exists(),
         {:ok, toml_data} <- parse_toml(toml_path) do
      old_version = Map.get(toml_data.package, :version, "unknown")

      updated_package = Map.put(toml_data.package, :version, new_version)
      updated_data = Map.put(toml_data, :package, updated_package)

      File.write!(toml_path, render_toml(updated_data))
      {:ok, %{old_version: old_version, new_version: new_version}}
    end
  end

  @doc """
  Gets the current package version from Cargo.toml.

  ## Examples

      iex> Lux.Cargo.get_version()
      {:ok, "0.1.0"}
  """
  @spec get_version() :: {:ok, String.t()} | {:error, String.t()}
  def get_version do
    case read_local_toml() do
      {:ok, toml_data} ->
        {:ok, Map.get(toml_data.package, :version, "0.1.0")}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Computes a content hash for the Cargo.toml file for cache invalidation.

  ## Examples

      iex> Lux.Cargo.compute_hash()
      {:ok, "a1b2c3d4..."}
  """
  @spec compute_hash() :: {:ok, String.t()} | {:error, String.t()}
  def compute_hash do
    with {:ok, content} <- File.read(Path.join(@module_path, @toml_name)) do
      hash = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
      {:ok, hash}
    end
  end

  @doc """
  Caches a resolved dependency information entry.

  ## Examples

      iex> Lux.Cargo.cache_dependency(%{name: "serde", version: "1.0.0", hash: "abc123"})
      {:ok, "priv/cargo/cache/serde-1.0.0.json"}
  """
  @spec cache_dependency(cache_entry()) :: {:ok, String.t()} | {:error, String.t()}
  def cache_dependency(entry) when is_map(entry) do
    with :ok <- ensure_cache_path() do
      filename = "#{entry.name}-#{entry.version}.json"
      filepath = Path.join(@cache_path, filename)

      json_content =
        entry
        |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
        |> Jason.encode_pretty!(pretty: true)

      File.write(filepath, json_content)
      {:ok, filepath}
    end
  end

  @doc """
  Retrieves a cached dependency entry by name and version.

  ## Examples

      iex> Lux.Cargo.get_cached_dependency("serde", "1.0.0")
      {:ok, %{name: "serde", version: "1.0.0", ...}}

      iex> Lux.Cargo.get_cached_dependency("nonexistent", "1.0.0")
      {:error, "Dependency not found in cache: nonexistent@1.0.0"}
  """
  @spec get_cached_dependency(String.t(), String.t()) ::
          {:ok, cache_entry()} | {:error, String.t()}
  def get_cached_dependency(name, version) when is_binary(name) and is_binary(version) do
    filepath = Path.join(@cache_path, "#{name}-#{version}.json")

    case File.read(filepath) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, decoded} -> {:ok, decoded}
          {:error, reason} -> {:error, "Failed to decode cache: #{reason}"}
        end

      {:error, _} ->
        {:error, "Dependency not found in cache: #{name}@#{version}"}
    end
  end

  @doc """
  Lists all cached dependencies.

  ## Examples

      iex> Lux.Cargo.list_cached_dependencies()
      {:ok, [%{name: "serde", version: "1.0.0", ...}, ...]}
  """
  @spec list_cached_dependencies() :: {:ok, [cache_entry()]} | {:error, String.t()}
  def list_cached_dependencies do
    with :ok <- ensure_cache_path() do
      files =
        Path.wildcard(Path.join(@cache_path, "*.json"))
        |> Enum.map(fn filepath ->
          case File.read(filepath) do
            {:ok, content} -> Jason.decode(content) |> elem(1)
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      {:ok, files}
    end
  end

  @doc """
  Clears all cached dependency entries.

  ## Examples

      iex> Lux.Cargo.clear_cache()
      :ok
  """
  @spec clear_cache() :: :ok | {:error, String.t()}
  def clear_cache do
    case ensure_cache_path() do
      :ok ->
        files = Path.wildcard(Path.join(@cache_path, "*.json"))
        Enum.each(files, &File.rm/1)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Validates the local Cargo.toml against basic structural rules.

  Checks:
  - Package name is present and valid (alphanumeric + hyphens)
  - Version follows semver format
  - Dependencies have non-empty version strings

  ## Examples

      iex> Lux.Cargo.validate_toml()
      {:ok, %{valid: true, errors: []}}
  """
  @spec validate_toml() :: {:ok, %{valid: boolean(), errors: [String.t()]}} | {:error, String.t()}
  def validate_toml do
    with {:ok, toml_data} <- read_local_toml() do
      errors = []

      errors =
        case toml_data.package do
          %{name: name} when is_binary(name) and byte_size(name) > 0 -> errors
          _ -> ["Package name is missing or empty"]
        end

      errors =
        case toml_data.package do
          %{version: v} when is_binary(v) and String.match?(v, ~r/^\d+\.\d+\.\d+$/) -> errors
          _ -> ["Package version must be semver (e.g., \"1.0.0\")"]
        end

      errors =
        toml_data.dependencies
        |> Enum.filter(fn {_name, version} ->
          is_binary(version) and String.trim(version) == ""
        end)
        |> Enum.map(fn {name, _} -> "Dependency '#{name}' has empty version" end)
        |> Enum.concat(errors)

      valid? = errors == []
      {:ok, %{valid: valid?, errors: errors}}
    end
  end

  @doc """
  Generates a sample Cargo.toml template with common dependencies.

  ## Options

    * `:with_serde` - Include serde dependency (default: true)
    * `:with_tokio` - Include tokio dependency (default: true)
    * `:with_axum` - Include axum dependency (default: false)

  ## Examples

      iex> Lux.Cargo.generate_template()
      {:ok, "# [package]..." }
  """
  @spec generate_template(keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_template(opts \\ []) do
    with_serde = Keyword.get(opts, :with_serde, true)
    with_tokio = Keyword.get(opts, :with_tokio, true)
    with_axum = Keyword.get(opts, :with_axum, false)

    deps_lines =
      []
      |> maybe_dep(with_serde, "serde = { version = \"1.0\", features = [\"derive\"] }")
      |> maybe_dep(with_tokio, "tokio = { version = \"1.0\", features = [\"full\"] }")
      |> maybe_dep(with_axum, "axum = \"0.7\"")
      |> Enum.join("\n")

    template = """
    # Auto-generated Cargo.toml by Lux.Cargo
    # Generated at: #{DateTime.utc_now() |> DateTime.to_iso8601()}

    [package]
    name = "lux_rust_component"
    version = "0.1.0"
    edition = "2021"
    description = "Rust component managed by Lux framework"
    license = "MIT"

    [dependencies]
    #{deps_lines}

    [dev-dependencies]
    pretty_assertions = "1.0"

    [features]
    default = []
    full = ["serde/full"]
    """

    {:ok, template}
  end

  defp maybe_dep(lines, true, dep_line), do: lines ++ [dep_line]
  defp maybe_dep(lines, false, _dep_line), do: lines

  @doc """
  Runs `cargo check` on the local Cargo project to validate compilation.

  ## Options

    * `:timeout` - Timeout in milliseconds (default: 120000)

  ## Examples

      iex> Lux.Cargo.check()
      {:ok, "Checking lux_cargo_workspace v0.1.0 (...)"}

      iex> Lux.Cargo.check(timeout: 30000)
      {:error, :timeout}
  """
  @spec check(keyword()) :: {:ok, String.t()} | {:error, term()}
  def check(opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 120000)

    cmd = [
      "cargo",
      "check",
      "--manifest-path",
      Path.join(@module_path, @toml_name)
    ]

    case run_command(cmd, timeout) do
      {:ok, output} -> {:ok, output}
      {:error, :timeout} -> {:error, :timeout}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Runs `cargo build` on the local Cargo project.

  ## Options

    * `:release` - Build in release mode (default: false)
    * `:timeout` - Timeout in milliseconds (default: 300000)

  ## Examples

      iex> Lux.Cargo.build()
      {:ok, "Finished dev [unoptimized + debuginfo] target(s)"}

      iex> Lux.Cargo.build(release: true)
      {:ok, "Finished release [optimized] target(s)"}
  """
  @spec build(keyword()) :: {:ok, String.t()} | {:error, term()}
  def build(opts \\ []) do
    release = Keyword.get(opts, :release, false)
    timeout = Keyword.get(opts, :timeout, 300000)

    cmd = ["cargo", "build", "--manifest-path", Path.join(@module_path, @toml_name)]

    cmd = if release, do: cmd ++ ["--release"], else: cmd

    case run_command(cmd, timeout) do
      {:ok, output} -> {:ok, output}
      {:error, :timeout} -> {:error, :timeout}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Runs `cargo test` on the local Cargo project.

  ## Options

    * `:timeout` - Timeout in milliseconds (default: 300000)

  ## Examples

      iex> Lux.Cargo.test()
      {:ok, "test result: ok. 5 passed; 0 failed; 0 ignored"}
  """
  @spec test_run(keyword()) :: {:ok, String.t()} | {:error, term()}
  def test_run(opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 300000)

    cmd = [
      "cargo",
      "test",
      "--manifest-path",
      Path.join(@module_path, @toml_name)
    ]

    case run_command(cmd, timeout) do
      {:ok, output} -> {:ok, output}
      {:error, :timeout} -> {:error, :timeout}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns child_spec for starting the Cargo module supervisor.
  Ensures the module path and cache directory exist at application startup.
  """
  @spec child_spec(keyword()) :: :supervisor.child_spec()
  def child_spec(_opts \\ []) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :ensure_module_path, []},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @doc false
  def ensure_module_path do
    if File.exists?(@module_path) do
      :ok
    else
      File.mkdir_p!(@module_path)
      :ok
    end
  end

  defp ensure_cache_path do
    if File.exists?(@cache_path) do
      :ok
    else
      File.mkdir_p!(@cache_path)
      :ok
    end
  end

  defp ensure_toml_exists do
    toml_path = Path.join(@module_path, @toml_name)

    if File.exists?(toml_path) do
      {:ok, toml_path}
    else
      init()
      {:ok, toml_path}
    end
  end

  defp read_local_toml do
    toml_path = Path.join(@module_path, @toml_name)
    parse_toml(toml_path)
  end

  defp run_command(cmd, timeout_ms) do
    case System.cmd(Enum.at(cmd, 0), Enum.drop(cmd, 1),
           cd: @module_path,
           stderr_to_stdout: true,
           timeout: div(timeout_ms, 1000)
         ) do
      {output, 0} -> {:ok, output}
      {output, exit_code} -> {:error, "Exit code #{exit_code}: #{output}"}
    rescue
      ArgumentError -> {:error, :timeout}
      System.TimeoutError -> {:error, :timeout}
    end
  end
end
