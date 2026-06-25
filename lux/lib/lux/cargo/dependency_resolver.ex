defmodule Lux.Cargo.DependencyResolver do
  @moduledoc """
  Cargo dependency resolution system.

  Resolves version constraints, detects conflicts,
  and manages package caching for Rust dependencies.
  """

  alias Lux.Cargo.TOMLParser

  @doc """
  Resolves dependencies from a Cargo.toml file.

  Returns a map of package names to resolved versions.
  """
  @spec resolve(Path.t()) :: {:ok, map()} | {:error, String.t()}
  def resolve(path) do
    with {:ok, parsed} <- TOMLParser.parse_file(path),
         deps <- parsed.dependencies,
         resolved <- resolve_versions(deps) do
      {:ok, resolved}
    end
  end

  @doc """
  Checks for dependency conflicts.
  """
  @spec check_conflicts(map()) :: [] | [%{package: String.t(), conflicts: list()}]
  def check_conflicts(%{dependencies: deps, dev_dependencies: dev_deps}) do
    all_deps = Map.merge(deps, dev_deps, fn _k, v1, v2 -> [v1, v2] end)
    
    all_deps
    |> Enum.group_by(fn {_name, config} -> config.version end)
    |> Enum.filter(fn {_version, packages} -> length(packages) > 1 end)
    |> Enum.map(fn {version, packages} ->
      %{
        package: Enum.map(packages, fn {name, _} -> name end),
        version: version,
        conflict: true
      }
    end)
  end

  def check_conflicts(_), do: []

  @doc """
  Caches a dependency in the local registry.
  """
  @spec cache_dependency(String.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
  def cache_dependency(name, version, source) when is_binary(name) and is_binary(version) and is_binary(source) do
    cache_dir = Path.join(:code.priv_dir(:lux), "cargo_cache")
    dep_dir = Path.join(cache_dir, "#{name}-#{version}")
    
    File.mkdir_p!(dep_dir)
    File.write!(Path.join(dep_dir, "source"), source)
    File.write!(Path.join(dep_dir, "version"), version)
    
    :ok
  end

  def cache_dependency(_, _, _), do: {:error, "Invalid dependency parameters"}

  @doc """
  Gets cached dependencies.
  """
  @spec get_cached() :: [%{name: String.t(), version: String.t(), source: String.t()}]
  def get_cached do
    cache_dir = Path.join(:code.priv_dir(:lux), "cargo_cache")
    
    unless File.exists?(cache_dir) do
      return []
    end
    
    cache_dir
    |> File.ls!()
    |> Enum.filter(&String.starts_with?(&1, "lux-"))
    |> Enum.map(fn dir ->
      path = Path.join(cache_dir, dir)
      %{
        name: dir,
        version: File.read!(Path.join(path, "version")),
        source: File.read!(Path.join(path, "source"))
      }
    end)
  end

  defp resolve_versions(deps) do
    deps
    |> Enum.map(fn {name, config} ->
      version = Map.get(config, :version, "*")
      {name, %{version: version, resolved: resolve_version(version)}}
    end)
    |> Map.new()
  end

  defp resolve_version("*"), do: "latest"
  defp resolve_version("^" <> _ = v), do: v
  defp resolve_version("~" <> _ = v), do: v
  defp resolve_version(v) when is_binary(v), do: v
  defp resolve_version(_), do: "latest"
end
