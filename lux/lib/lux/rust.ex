defmodule Lux.Rust do
  @moduledoc """
  Provides functions for compiling and running Rust code via Cargo.

  Manages Rust projects inside `priv/rust/` and provides helpers
  for Cargo.toml manipulation, dependency management, and build commands.

  ## Examples

      iex> Lux.Rust.build()
      {:ok, "Compiled successfully"}

      iex> Lux.Rust.test()
      {:ok, "Tests passed"}
  """

  @priv_rust_dir Application.app_dir(:lux, "priv/rust")

  @doc """
  Runs a Cargo command in the priv/rust directory.

  ## Options
    * `:cd` - Working directory (default: priv/rust)
    * `:timeout` - Command timeout in milliseconds (default: 120_000)

  ## Examples

      iex> Lux.Rust.cargo(["build", "--release"])
      {:ok, "..."}

      iex> Lux.Rust.cargo(["test"])
      {:ok, "..."}
  """
  @spec cargo([String.t()], keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def cargo(args, opts \\ []) when is_list(args) do
    work_dir = Keyword.get(opts, :cd, @priv_rust_dir)
    timeout = Keyword.get(opts, :timeout, 120_000)

    case System.cmd("cargo", args, cd: work_dir, stderr_to_stdout: true, timeout: timeout) do
      {output, 0} -> {:ok, String.trim(output)}
      {output, _} -> {:error, String.trim(output)}
    end
  rescue
    e in ErlangError ->
      case e do
        %ErlangError{original: :enoent} -> {:error, "cargo not found in PATH"}
        _ -> {:error, inspect(e)}
      end
  end

  @doc """
  Builds the Rust project.

  ## Options
    * `:release` - Build in release mode (default: false)
    * `:cd` - Working directory

  ## Examples

      iex> Lux.Rust.build(release: true)
      {:ok, "Compiled successfully"}
  """
  @spec build(keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def build(opts \\ []) do
    args = if Keyword.get(opts, :release), do: ["build", "--release"], else: ["build"]
    cargo(args, opts)
  end

  @doc """
  Runs `cargo test` in the Rust project.

  ## Options
    * `:cd` - Working directory

  ## Examples

      iex> Lux.Rust.test()
      {:ok, "running 1 test ... ok"}
  """
  @spec test(keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def test(opts \\ []) do
    cargo(["test"], opts)
  end

  @doc """
  Runs `cargo check` for fast compilation checks.
  """
  @spec check(keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def check(opts \\ []) do
    cargo(["check"], opts)
  end

  @doc """
  Reads and parses a Cargo.toml manifest.

  Returns a map with :dependencies, :dev_dependencies, :build_dependencies,
  :package metadata, and raw TOML string.

  ## Examples

      iex> Lux.Rust.read_manifest()
      {:ok, %{dependencies: %{"serde" => "1.0"}, package: %{name: "my_project", version: "0.1.0"}}}

      iex> Lux.Rust.read_manifest("path/to/Cargo.toml")
      {:ok, %{...}}
  """
  @spec read_manifest(String.t()) :: {:ok, map()} | {:error, String.t()}
  def read_manifest(path \\ nil) do
    manifest_path = resolve_manifest(path)

    case File.read(manifest_path) do
      {:ok, content} ->
        parsed = parse_toml(content)
        {:ok, parsed}

      {:error, reason} ->
        {:error, "Failed to read Cargo.toml: #{reason}"}
    end
  end

  @doc """
  Writes a Cargo.toml manifest.

  The manifest should have the same structure as returned by `read_manifest/1`.
  """
  @spec write_manifest(map(), String.t()) :: :ok | {:error, String.t()}
  def write_manifest(manifest, path \\ nil) do
    manifest_path = resolve_manifest(path)

    toml_string = encode_toml(manifest)

    case File.write(manifest_path, toml_string) do
      :ok -> :ok
      {:error, reason} -> {:error, "Failed to write Cargo.toml: #{reason}"}
    end
  end

  @doc """
  Adds a dependency to Cargo.toml.

  ## Examples

      iex> Lux.Rust.add_dependency("serde", "1.0")
      :ok

      iex> Lux.Rust.add_dependency("serde", "1.0", type: :dev)
      :ok

      iex> Lux.Rust.add_dependency("my-dep", git: "https://github.com/user/repo")
      :ok
  """
  @spec add_dependency(String.t(), String.t() | keyword(), keyword()) :: :ok | {:error, String.t()}
  def add_dependency(name, version_or_opts, opts \\ []) do
    dep_type = Keyword.get(opts, :type, :normal)

    with {:ok, manifest} <- read_manifest(),
         {:ok, manifest} <- do_add_dependency(manifest, name, version_or_opts, dep_type) do
      write_manifest(manifest)
    end
  end

  @doc """
  Removes a dependency from Cargo.toml.

  ## Examples

      iex> Lux.Rust.remove_dependency("serde")
      :ok

      iex> Lux.Rust.remove_dependency("serde", type: :dev)
      :ok
  """
  @spec remove_dependency(String.t(), keyword()) :: :ok | {:error, String.t()}
  def remove_dependency(name, opts \\ []) do
    dep_type = Keyword.get(opts, :type, :normal)

    with {:ok, manifest} <- read_manifest(),
         {:ok, manifest} <- do_remove_dependency(manifest, name, dep_type) do
      write_manifest(manifest)
    end
  end

  @doc """
  Searches for crates on crates.io via the crates.io API.

  ## Examples

      iex> Lux.Rust.search_crates("serde")
      {:ok, [%{name: "serde", description: "...", version: "1.0.0"}]}
  """
  @spec search_crates(String.t()) :: {:ok, list(map())} | {:error, String.t()}
  def search_crates(query) when is_binary(query) do
    url = "https://crates.io/api/v1/crates?q=#{URI.encode(query)}&per_page=10"

    headers = [
      {"User-Agent", "lux-rust/0.1.0"},
      {"Accept", "application/json"}
    ]

    case Req.get!(url, headers: headers) do
      %{status: 200, body: %{"crates" => crates}} ->
        results =
          Enum.map(crates, fn c ->
            %{
              name: c["id"],
              description: c["description"],
              version: c["max_version"],
              downloads: c["downloads"]
            }
          end)

        {:ok, results}

      %{status: status, body: body} ->
        {:error, "crates.io API returned #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Failed to query crates.io: #{inspect(reason)}"}
    end
  end

  @doc """
  Creates a new Rust library project in priv/rust.

  ## Examples

      iex> Lux.Rust.new_project("my_crate")
      :ok
  """
  @spec new_project(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def new_project(name) when is_binary(name) do
    case cargo(["init", "--lib", name], cd: @priv_rust_dir) do
      {:ok, output} -> {:ok, "Created project #{name}: #{output}"}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns the priv/rust directory path.
  """
  @spec module_path() :: String.t()
  def module_path, do: @priv_rust_dir

  # Resolves the manifest path
  defp resolve_manifest(nil), do: Path.join(@priv_rust_dir, "Cargo.toml")
  defp resolve_manifest(path) when is_binary(path), do: path

  # Adds a dependency to the manifest
  defp do_add_dependency(manifest, name, version, :normal) when is_binary(version) do
    deps = Map.put(manifest.dependencies || %{}, name, version)
    {:ok, %{manifest | dependencies: deps}}
  end

  defp do_add_dependency(manifest, name, version, :dev) when is_binary(version) do
    deps = Map.put(manifest.dev_dependencies || %{}, name, version)
    {:ok, %{manifest | dev_dependencies: deps}}
  end

  defp do_add_dependency(manifest, name, version, :build) when is_binary(version) do
    deps = Map.put(manifest.build_dependencies || %{}, name, version)
    {:ok, %{manifest | build_dependencies: deps}}
  end

  defp do_add_dependency(manifest, name, git_opts, dep_type) when is_list(git_opts) do
    dep_value = format_git_dep(git_opts)

    case dep_type do
      :normal ->
        deps = Map.put(manifest.dependencies || %{}, name, dep_value)
        {:ok, %{manifest | dependencies: deps}}

      :dev ->
        deps = Map.put(manifest.dev_dependencies || %{}, name, dep_value)
        {:ok, %{manifest | dev_dependencies: deps}}

      :build ->
        deps = Map.put(manifest.build_dependencies || %{}, name, dep_value)
        {:ok, %{manifest | build_dependencies: deps}}
    end
  end

  # Removes a dependency from the manifest
  defp do_remove_dependency(manifest, name, :normal) do
    deps = Map.drop(manifest.dependencies || %{}, [name])
    {:ok, %{manifest | dependencies: deps}}
  end

  defp do_remove_dependency(manifest, name, :dev) do
    deps = Map.drop(manifest.dev_dependencies || %{}, [name])
    {:ok, %{manifest | dev_dependencies: deps}}
  end

  defp do_remove_dependency(manifest, name, :build) do
    deps = Map.drop(manifest.build_dependencies || %{}, [name])
    {:ok, %{manifest | build_dependencies: deps}}
  end

  # Formats a git dependency spec
  defp format_git_dep(opts) do
    branch = if b = opts[:branch], do: %{"branch" => b}, else: %{}
    tag = if t = opts[:tag], do: %{"tag" => t}, else: %{}
    rev = if r = opts[:rev], do: %{"rev" => r}, else: %{}

    %{"git" => opts[:git]} |> Map.merge(branch) |> Map.merge(tag) |> Map.merge(rev)
  end

  # Parses a TOML string into structured manifest
  defp parse_toml(content) do
    lines = String.split(content, "\n")
    parse_toml_lines(lines, %{}, nil)
  end

  defp parse_toml_lines([], manifest, _), do: manifest

  defp parse_toml_lines([line | rest], manifest, current_section) do
    trimmed = String.trim(line)

    cond do
      String.starts_with?(trimmed, "[") ->
        section = trimmed |> String.trim("[") |> String.trim("]")
        parse_toml_lines(rest, manifest, section)

      String.starts_with?(trimmed, "#") or trimmed == "" ->
        parse_toml_lines(rest, manifest, current_section)

      current_section != nil and String.contains?(trimmed, "=") ->
        [key, value] = String.split(trimmed, "=", parts: 2)
        key = String.trim(key)
        value = String.trim(value)

        manifest = update_section(manifest, current_section, key, parse_toml_value(value))
        parse_toml_lines(rest, manifest, current_section)

      true ->
        parse_toml_lines(rest, manifest, current_section)
    end
  end

  defp update_section(manifest, "package", key, value) do
    pkg = Map.get(manifest, :package, %{})
    Map.put(manifest, :package, Map.put(pkg, key, value))
  end

  defp update_section(manifest, "dependencies", key, value) do
    deps = Map.get(manifest, :dependencies, %{})
    Map.put(manifest, :dependencies, Map.put(deps, key, value))
  end

  defp update_section(manifest, "dev-dependencies", key, value) do
    deps = Map.get(manifest, :dev_dependencies, %{})
    Map.put(manifest, :dev_dependencies, Map.put(deps, key, value))
  end

  defp update_section(manifest, "build-dependencies", key, value) do
    deps = Map.get(manifest, :build_dependencies, %{})
    Map.put(manifest, :build_dependencies, Map.put(deps, key, value))
  end

  defp update_section(manifest, _section, _key, _value), do: manifest

  defp parse_toml_value(value) do
    quoted = value |> String.trim()
    cond do
      String.starts_with?(quoted, "\"") and String.ends_with?(quoted, "\"") ->
        quoted |> String.slice(1..-2//1)

      quoted == "true" -> true
      quoted == "false" -> false
      String.contains?(quoted, ".") -> String.to_float(quoted)
      true ->
        case Integer.parse(quoted) do
          {int, ""} -> int
          _ -> quoted
        end
    end
  rescue
    _ -> value
  end

  # Encodes manifest back to TOML string
  defp encode_toml(manifest) do
    parts = []

    parts = if pkg = manifest[:package] do
      parts ++ [encode_section("package", pkg)]
    else
      parts
    end

    parts = if deps = manifest[:dependencies], deps != %{} do
      parts ++ [encode_section("dependencies", deps)]
    else
      parts
    end

    parts = if deps = manifest[:dev_dependencies], deps != %{} do
      parts ++ [encode_section("dev-dependencies", deps)]
    else
      parts
    end

    parts = if deps = manifest[:build_dependencies], deps != %{} do
      parts ++ [encode_section("build-dependencies", deps)]
    else
      parts
    end

    Enum.join(parts, "\n") <> "\n"
  end

  defp encode_section(_name, deps) when is_map(deps) do
    entries =
      Enum.map(deps, fn {key, value} ->
        "  #{key} = #{encode_toml_value(value)}"
      end)

    section_name = if is_binary(deps), do: deps, else: nil

    if section_name do
      "[#{section_name}]"
    else
      ""
    end
  end

  defp encode_section(name, map) when is_map(map) do
    entries =
      Enum.map(map, fn {key, value} ->
        "  #{key} = #{encode_toml_value(value)}"
      end)

    ["[#{name}]" | entries] |> Enum.join("\n")
  end

  defp encode_toml_value(value) when is_binary(value), do: ~s/"#{value}"/
  defp encode_toml_value(value) when is_integer(value), do: Integer.to_string(value)
  defp encode_toml_value(value) when is_float(value), do: Float.to_string(value)
  defp encode_toml_value(value) when is_boolean(value), do: if(value, do: "true", else: "false")

  defp encode_toml_value(map) when is_map(map) do
    entries =
      Enum.map_join(map, ", ", fn {k, v} ->
        ~s/#{k} = "#{v}"/
      end)

    "{#{entries}}"
  end
end
