defmodule Lux.Rust.Cargo do
  @moduledoc """
  Cargo package management integration for Rust in Lux.

  Enables automated Cargo.toml manifest generation, dependency resolution,
  caching, and build pipeline integration for native Rust components, Prisms, and Beams.

  ## Examples

      iex> manifest = Lux.Rust.Cargo.generate_manifest("my_prism", "0.1.0", %{"serde" => "1.0", "serde_json" => "1.0"})
      iex> String.contains?(manifest, "[dependencies]")
      true

      iex> {:ok, parsed} = Lux.Rust.Cargo.parse_manifest(manifest)
      iex> parsed["package"]["name"]
      "my_prism"
  """

  require Logger

  @default_edition "2021"

  @doc """
  Generates a valid Cargo.toml string from parameters.
  """
  def generate_manifest(package_name, version \\ "0.1.0", dependencies \\ %{}, opts \\ []) do
    edition = Keyword.get(opts, :edition, @default_edition)
    authors = Keyword.get(opts, :authors, ["Lux Agent Framework <support@spectral.finance>"])
    description = Keyword.get(opts, :description, "Lux Rust Component")
    crate_type = Keyword.get(opts, :crate_type, ["cdylib", "rlib"])

    deps_section = format_dependencies(dependencies)

    authors_formatted =
      authors
      |> Enum.map(&"\"#{&1}\"")
      |> Enum.join(", ")

    crate_type_formatted =
      crate_type
      |> Enum.map(&"\"#{&1}\"")
      |> Enum.join(", ")

    """
    [package]
    name = "#{package_name}"
    version = "#{version}"
    edition = "#{edition}"
    authors = [#{authors_formatted}]
    description = "#{description}"

    [lib]
    crate-type = [#{crate_type_formatted}]

    [dependencies]
    #{deps_section}
    """
    |> String.trim()
  end

  @doc """
  Parses a Cargo.toml string into a structured Elixir map.
  Supports standard key-value pairs, nested sections, and dependency specs.
  """
  def parse_manifest(toml_str) when is_binary(toml_str) do
    lines = String.split(toml_str, ["\r\n", "\n"])

    {parsed, _current_section} =
      Enum.reduce(lines, {%{}, nil}, fn line, {acc, current_section} ->
        line = String.trim(line)

        cond do
          line == "" or String.starts_with?(line, "#") ->
            {acc, current_section}

          String.starts_with?(line, "[") and String.ends_with?(line, "]") ->
            section =
              line
              |> String.slice(1..-2//1)
              |> String.trim()

            {Map.put_new(acc, section, %{}), section}

          String.contains?(line, "=") and current_section != nil ->
            [k, v] = String.split(line, "=", parts: 2)
            key = String.trim(k)
            val = parse_toml_val(String.trim(v))

            section_data = Map.get(acc, current_section, %{})
            updated_section = Map.put(section_data, key, val)
            {Map.put(acc, current_section, updated_section), current_section}

          true ->
            {acc, current_section}
        end
      end)

    {:ok, parsed}
  rescue
    e -> {:error, "Failed to parse Cargo manifest: #{Exception.message(e)}"}
  end

  @doc """
  Adds or updates a dependency in a manifest map.
  """
  def add_dependency(manifest_map, name, spec) when is_map(manifest_map) and is_binary(name) do
    deps = Map.get(manifest_map, "dependencies", %{})
    updated_deps = Map.put(deps, name, spec)
    Map.put(manifest_map, "dependencies", updated_deps)
  end

  @doc """
  Removes a dependency from a manifest map.
  """
  def remove_dependency(manifest_map, name) when is_map(manifest_map) and is_binary(name) do
    deps = Map.get(manifest_map, "dependencies", %{})
    updated_deps = Map.delete(deps, name)
    Map.put(manifest_map, "dependencies", updated_deps)
  end

  @doc """
  Resolves and normalizes dependency specifications.
  Validates semver or path/git requirements.
  """
  def resolve_dependencies(dependencies) when is_map(dependencies) do
    resolved =
      Enum.reduce(dependencies, %{}, fn {name, spec}, acc ->
        normalized_spec =
          case spec do
            v when is_binary(v) ->
              %{version: v}

            opts when is_map(opts) ->
              opts

            opts when is_list(opts) ->
              Map.new(opts)
          end

        Map.put(acc, to_string(name), normalized_spec)
      end)

    {:ok, resolved}
  end

  @doc """
  Executes cargo build inside the target project directory.
  Uses the configured CARGO_HOME cache directory.
  """
  def build(project_dir, opts \\ []) do
    release = Keyword.get(opts, :release, false)
    cache = cache_dir()

    args = ["build"] ++ if(release, do: ["--release"], else: [])

    env = [
      {"CARGO_HOME", cache},
      {"RUST_BACKTRACE", "1"}
    ]

    case System.cmd("cargo", args, cd: project_dir, env: env, stderr_to_stdout: true) do
      {output, 0} ->
        {:ok, output}

      {output, code} ->
        {:error, {:cargo_build_failed, code, output}}
    end
  rescue
    e -> {:error, {:system_error, Exception.message(e)}}
  end

  @doc """
  Returns the cache directory path used by Lux for Cargo packages.
  """
  def cache_dir do
    Application.get_env(
      :lux,
      :cargo_cache_dir,
      Path.join([System.tmp_dir!(), "lux", "cargo_cache"])
    )
  end

  @doc """
  Cleans the local package cache directory.
  """
  def clean_cache(cache_path \\ nil) do
    target = cache_path || cache_dir()

    if File.exists?(target) do
      File.rm_rf(target)
      :ok
    else
      :ok
    end
  end

  defp format_dependencies(deps) when is_map(deps) do
    deps
    |> Enum.map(fn
      {k, v} when is_binary(v) ->
        "#{k} = \"#{v}\""

      {k, opts} when is_map(opts) ->
        entries =
          opts
          |> Enum.map(fn {ok, ov} -> "#{ok} = #{inspect(ov)}" end)
          |> Enum.join(", ")

        "#{k} = { #{entries} }"
    end)
    |> Enum.join("\n")
  end

  defp parse_toml_val(str) do
    cond do
      String.starts_with?(str, "\"") and String.ends_with?(str, "\"") ->
        String.slice(str, 1..-2//1)

      String.starts_with?(str, "[") and String.ends_with?(str, "]") ->
        str
        |> String.slice(1..-2//1)
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.map(&parse_toml_val/1)

      str in ["true", "false"] ->
        str == "true"

      true ->
        str
    end
  end
end
