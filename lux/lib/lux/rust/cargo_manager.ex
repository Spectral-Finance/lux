defmodule Lux.Rust.CargoManager do
  @moduledoc """
  Cargo package management for Rust in Lux.

  Supports:
  - Cargo.toml generation and parsing
  - Dependency add/remove/resolution with semver validation
  - Build command generation (profile, target, features)
  - Version management (bump major/minor/patch)
  - Package cache key generation (SHA256)

  ## Example

      {:ok, toml} = CargoManager.generate_toml(%{name: "my_crate", version: "1.0.0", dependencies: %{serde: "1.0"}})
      {:ok, parsed} = CargoManager.parse_toml(toml)
      {:ok, new_ver} = CargoManager.bump_version("1.2.3", :minor)
  """

  @default_edition "2021"

  @type dep_spec :: String.t() | %{version: String.t(), features: [String.t()]}

  @spec generate_toml(map()) :: {:ok, String.t()} | {:error, atom()}
  def generate_toml(config) do
    name = config[:name]
    version = config[:version] || "0.1.0"

    cond do
      is_nil(name) or name == "" -> {:error, :missing_name}
      not semver_valid?(version) -> {:error, :invalid_version}
      true ->
        edition = config[:edition] || @default_edition
        deps = config[:dependencies] || %{}

        toml = """
        [package]
        name = "#{name}"
        version = "#{version}"
        edition = "#{edition}"

        [dependencies]
        #{format_deps(deps)}
        """
        {:ok, String.trim(toml)}
    end
  end

  @spec parse_toml(String.t()) :: {:ok, map()} | {:error, atom()}
  def parse_toml(content) when is_binary(content) do
    lines = String.split(content, "\n")
    {result, _section} = Enum.reduce(lines, {%{}, nil}, fn line, {acc, section} ->
      line = String.trim(line)
      cond do
        String.starts_with?(line, "[") ->
          section_name = line |> String.trim_leading("[") |> String.trim_trailing("]") |> String.trim()
          {acc, section_name}
        String.contains?(line, "=") && section != nil ->
          [key, val] = String.split(line, "=", parts: 2)
          key = String.trim(key)
          val = val |> String.trim() |> String.trim("\"")
          section_map = Map.get(acc, section, %{})
          {Map.put(acc, section, Map.put(section_map, key, val)), section}
        true ->
          {acc, section}
      end
    end)
    {:ok, result}
  end
  def parse_toml(_), do: {:error, :invalid_input}

  @spec add_dependency(map(), atom() | String.t(), String.t(), map()) :: {:ok, map()}
  def add_dependency(config, name, version, opts \\ %{}) do
    deps = Map.get(config, :dependencies, %{})
    dep = Map.merge(%{version: version}, opts)
    {:ok, Map.put(config, :dependencies, Map.put(deps, name, dep))}
  end

  @spec remove_dependency(map(), atom() | String.t()) :: {:ok, map()} | {:error, atom()}
  def remove_dependency(config, name) do
    deps = Map.get(config, :dependencies, %{})
    if Map.has_key?(deps, name) do
      {:ok, Map.put(config, :dependencies, Map.delete(deps, name))}
    else
      {:error, :not_found}
    end
  end

  @spec resolve_dependencies(map()) :: {:ok, map()} | {:error, map()}
  def resolve_dependencies(deps) when is_map(deps) do
    resolved = Enum.map(deps, fn {name, spec} ->
      version = if is_map(spec), do: spec[:version] || "0.0.0", else: to_string(spec)
      {name, %{version: version, compatible: semver_valid?(version)}}
    end)
    conflicts = Enum.filter(resolved, fn {_n, v} -> !v.compatible end)

    if conflicts == [] do
      {:ok, %{resolved: Map.new(resolved), conflicts: []}}
    else
      {:error, %{conflicts: Enum.map(conflicts, &elem(&1, 0))}}
    end
  end

  @spec cache_key(map()) :: {:ok, String.t()}
  def cache_key(config) do
    hash = :crypto.hash(:sha256, :erlang.term_to_binary(config))
           |> Base.encode16(case: :lower)
           |> binary_part(0, 16)
    {:ok, hash}
  end

  @spec build_command(keyword()) :: {:ok, String.t()}
  def build_command(opts \\ []) do
    profile = opts[:profile] || :release
    target = opts[:target]
    features = opts[:features] || []

    cmd = ["cargo", "build"]
    cmd = if profile == :release, do: cmd ++ ["--release"], else: cmd
    cmd = if target, do: cmd ++ ["--target", target], else: cmd
    cmd = if features != [], do: cmd ++ ["--features", Enum.join(features, ",")], else: cmd

    {:ok, Enum.join(cmd, " ")}
  end

  @spec bump_version(String.t(), :major | :minor | :patch) :: {:ok, String.t()} | {:error, atom()}
  def bump_version(version, level \\ :patch) do
    case String.split(version, ".") do
      [major, minor, patch] ->
        with {maj, ""} <- Integer.parse(major),
             {min, ""} <- Integer.parse(minor),
             {pat, ""} <- Integer.parse(patch) do
          new = case level do
            :major -> "#{maj + 1}.0.0"
            :minor -> "#{maj}.#{min + 1}.0"
            :patch -> "#{maj}.#{min}.#{pat + 1}"
          end
          {:ok, new}
        else
          _ -> {:error, :invalid_version}
        end
      _ -> {:error, :invalid_version}
    end
  end

  # --- Private ---

  defp format_deps(deps) do
    Enum.map_join(deps, "\n", fn {name, spec} ->
      case spec do
        %{version: v, features: f} ->
          features = Enum.map_join(f, ", ", &"\"#{&1}\"")
          "#{name} = { version = \"#{v}\", features = [#{features}] }"
        %{version: v} -> "#{name} = \"#{v}\""
        v when is_binary(v) -> "#{name} = \"#{v}\""
        _ -> "#{name} = \"#{inspect(spec)}\""
      end
    end)
  end

  defp semver_valid?(version) when is_binary(version) do
    case String.split(version, ".") do
      [maj, min, pat] ->
        Enum.all?([maj, min, pat], fn s ->
          case Integer.parse(s) do
            {_, ""} -> true
            _ -> false
          end
        end)
      _ -> false
    end
  end
  defp semver_valid?(_), do: false
end
