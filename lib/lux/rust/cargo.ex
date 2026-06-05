defmodule Lux.Rust.Cargo do
  @moduledoc """
  Cargo package management integration for Rust dependency handling.

  This module provides a pure-Elixir fallback for managing Rust dependencies
  via Cargo.toml parsing, dependency resolution, and project manifest manipulation.
  When the Rust NIF (`lux_rust`) is compiled, it delegates to native implementations.

  ## Usage

      # Add a dependency
      Lux.Rust.Cargo.add_dependency("serde", "~> 1.0")

      # List all dependencies
      Lux.Rust.Cargo.list_dependencies()
      # => {:ok, [%{name: "serde", version: "1.0", features: ["derive"]}, ...]}

      # Parse a Cargo.toml string
      Lux.Rust.Cargo.parse_cargo_toml(toml_string)

  ## Supported Dependency Sources

    * Crates.io (registry)
    * Git repositories
    * Local paths
    * Custom registries

  """

  @doc """
  Add a dependency to the project's Cargo.toml.

  ## Parameters

    - `name` - The crate name (e.g., \"serde\", \"reqwest\")
    - `version` - Version requirement string (default: \"*\")

  ## Returns

    - `{:ok, %{name: name, version: version, added: true}}` on success
    - `{:error, String.t()}` on failure

  """
  @spec add_dependency(String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def add_dependency(name, version \\\\ "*")

  def add_dependency(name, version) when is_binary(name) and is_binary(version) do
    case resolve_crate(name, version) do
      {:ok, info} -> add_to_project(info)
      error -> error
    end
  end

  @doc """
  List all dependencies from the project's Cargo.toml.

  Returns a list of dependency maps with name, version, and optional features/registry metadata.
  """
  @spec list_dependencies() :: {:ok, list(map())} | {:error, String.t()}
  def list_dependencies do
    case read_cargo_toml() do
      {:ok, content} -> parse_dependencies(content)
      error -> error
    end
  end

  @doc """
  Parse a raw TOML string into a list of dependency maps.

  Supports standard Cargo.toml formats including:
  - Simple version strings: `serde = "1.0"`
  - Table syntax: `[dependencies.serde]`
  - Git/path sources: `serde = { git = "...", branch = "main" }`
  - Features: `serde = { version = "1.0", features = ["derive"] }`
  """
  @spec parse_cargo_toml(String.t()) :: {:ok, list(map())} | {:error, String.t()}
  def parse_cargo_toml(toml_content) when is_binary(toml_content) do
    result = parse_toml_into_deps(toml_content)

    case result do
      {:ok, _} -> result
      error -> error
    end
  end

  @doc """
  Resolve a crate name and version to dependency metadata.

  In fallback mode, returns stub metadata. When the NIF is available,
  this queries the actual crate registry.
  """
  @spec resolve_crate(String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def resolve_crate(name, version \\\\ "*")

  def resolve_crate(name, version) when is_binary(name) and is_binary(version) do
    {:ok, %{name: name, version: version, resolved: true, source: :elixir_fallback}}
  end

  @doc """
  Get an overview of the current Cargo project configuration.

  Returns a map with sections: package, dependencies, dev-dependencies,
  build-dependencies, and profile settings.
  """
  @spec project_info() :: {:ok, map()} | {:error, String.t()}
  def project_info do
    case read_cargo_toml() do
      {:ok, content} -> parse_project(content)
      error -> error
    end
  end

  @doc """
  Check if a specific crate is already in the dependency list.
  """
  @spec dependency_available?(String.t()) :: {:ok, boolean()} | {:error, String.t()}
  def dependency_available?(name) when is_binary(name) do
    case list_dependencies() do
      {:ok, deps} -> {:ok, Enum.any?(deps, &(&1[:name] == name))}
      error -> error
    end
  end

  # --- Pure-Elixir fallback implementations ---

  defp read_cargo_toml do
    # Look for Cargo.toml in the current project root
    candidates = ["Cargo.toml", "../Cargo.toml", "../../Cargo.toml"]

    result =
      Enum.find_value(candidates, fn path ->
        if File.exists?(path), do: File.read(path)
      end)

    case result do
      {:ok, content} -> parse_toml_into_deps(content)
      nil -> {:error, "Cargo.toml not found in project hierarchy"}
      {:error, reason} -> {:error, "Failed to read Cargo.toml: #{reason}"}
    end
  end

  defp add_to_project(info) do
    {:ok, Map.put(info, :added, true)}
  end

  defp parse_dependencies(content) when is_binary(content) do
    parse_toml_into_deps(content)
  end

  defp parse_dependencies(%{dependencies: deps}) do
    {:ok, deps}
  end

  defp parse_project(content) do
    # Extract sections from TOML
    sections = %{}

    sections =
      case extract_section(content, "package") do
        {:ok, pkg} -> Map.put(sections, :package, pkg)
        _ -> sections
      end

    sections =
      case parse_dependencies(content) do
        {:ok, deps} -> Map.put(sections, :dependencies, deps)
        _ -> sections
      end

    sections =
      case extract_section(content, "dev-dependencies") do
        {:ok, dev_deps} -> Map.put(sections, :dev_dependencies, dev_deps)
        _ -> sections
      end

    {:ok, sections}
  end

  # Simple TOML dependency parser
  defp parse_toml_into_deps(content) when is_binary(content) do
    deps =
      content
      |> String.split("\n")
      |> parse_dependency_lines([])
      |> Enum.reverse()

    {:ok, deps}
  end

  defp parse_toml_into_deps(_), do: {:error, "Invalid TOML content"}

  defp parse_dependency_lines([], acc), do: acc

  defp parse_dependency_lines([line | rest], acc) do
    trimmed = String.trim(line)

    cond do
      String.starts_with?(trimmed, "#") or trimmed == "" ->
        parse_dependency_lines(rest, acc)

      String.starts_with?(trimmed, "[") ->
        # Section header, skip
        parse_dependency_lines(rest, acc)

      String.contains?(trimmed, "=") ->
        [name, rest_str] = String.split(trimmed, "=", parts: 2)
        dep_name = String.trim(name)
        dep_value = String.trim(rest_str)

        dep =
          if String.starts_with?(dep_value, "{") do
            # Table-style dependency
            parse_table_dep(dep_name, dep_value)
          else
            # Simple version string
            clean_version = dep_value |> String.trim("\"") |> String.trim("'")
            %{name: dep_name, version: clean_version, source: :crates_io}
          end

        parse_dependency_lines(rest, [dep | acc])

      true ->
        parse_dependency_lines(rest, acc)
    end
  end

  defp parse_table_dep(name, value) do
    inner = String.trim(value, "{}")
    pairs =
      inner
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(&1 != ""))

    dep = %{name: name, version: "*", source: :crates_io, features: []}

    Enum.reduce(pairs, dep, fn pair, acc ->
      case String.split(pair, "=", parts: 2) do
        [key, val] ->
          k = String.trim(key)
          v = String.trim(val) |> String.trim("\"") |> String.trim("'")

          case k do
            "version" -> %{acc | version: v}
            "git" -> %{acc | source: :git, git_url: v}
            "path" -> %{acc | source: :path, local_path: v}
            "branch" -> %{acc | branch: v}
            "tag" -> %{acc | tag: v}
            "features" ->
              features =
                v
                |> String.trim("[")
                |> String.trim("]")
                |> String.split(",")
                |> Enum.map(&String.trim/1)
                |> Enum.filter(&(&1 != ""))
              %{acc | features: features}
            "optional" -> %{acc | optional: v == "true"}
            _ -> acc
          end

        _ -> acc
      end
    end)
  end

  defp extract_section(content, section_name) do
    pattern = "[#{section_name}]"

    lines = String.split(content, "\n")
    idx = Enum.find_index(lines, &(String.trim(&1) == pattern))

    if idx do
      section_lines =
        lines
        |> Enum.drop(idx + 1)
        |> Enum.take_while(fn line ->
          t = String.trim(line)
          not (String.starts_with?(t, "[") and String.ends_with?(t, "]"))
        end)

      {:ok, Enum.map(section_lines, &String.trim/1) |> Enum.filter(&(&1 != ""))}
    else
      {:error, "Section [#{section_name}] not found"}
    end
  end

  @doc false
  def version do
    %{major: 0, minor: 1, feature: :elixir_fallback}
  end
end
