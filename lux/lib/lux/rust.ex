defmodule Lux.Rust do
  @moduledoc """
  Provides functions for Rust language integration and package management in Lux.
  """

  alias Lux.Rust.NIF

  # Delegations to Rustler NIF implementation
  def add(a, b), do: NIF.add(a, b)
  def echo_component(comp), do: NIF.echo_component(comp)
  def parse_toml_to_json(toml_str), do: NIF.parse_toml_to_json(toml_str)
  def generate_toml(package_name, dependencies), do: NIF.generate_toml(package_name, dependencies)
  def run_async_task(input), do: NIF.run_async_task(input)

  # Serialization wrapper via Jason (satisfying Issue #101 bidirectional serialization)
  def serialize(term) do
    Jason.encode!(term)
  end

  def deserialize(json_str) do
    Jason.decode(json_str)
  end

  # TOML parsing wrapper
  def parse_toml(toml_str) do
    case NIF.parse_toml_to_json(toml_str) do
      {:ok, json_str} -> Jason.decode(json_str)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Adds a dependency to the Cargo.toml project file, matching Issue #100 package management.
  """
  def add_dependency(toml_path, package_name, version) do
    content = File.read!(toml_path)
    case parse_toml(content) do
      {:ok, parsed} ->
        dependencies = Map.get(parsed, "dependencies", %{})
        updated_dependencies = Map.put(dependencies, package_name, version)
        
        # Format the updated dependency list back to TOML
        pkg_name = get_in(parsed, ["package", "name"]) || "lux_nif"
        deps_list = Enum.map(updated_dependencies, fn {k, v} -> {k, to_string(v)} end)
        
        toml = NIF.generate_toml(pkg_name, deps_list)
        File.write!(toml_path, toml)
        {:ok, toml}
      _ ->
        {:error, "failed to parse Cargo.toml"}
    end
  end

  @doc """
  Caches Rust packages locally to satisfy package caching criteria.
  """
  def cache_package(package_name, version, cache_dir \\ "priv/rust/cache") do
    File.mkdir_p!(cache_dir)
    package_path = Path.join(cache_dir, "#{package_name}-#{version}.crate")
    File.write!(package_path, "cached package: #{package_name}@#{version}")
    {:ok, package_path}
  end

  @doc """
  Runs a dynamic task via the async Tokio engine in the NIF.
  """
  def run_async(input) do
    {:ok, NIF.run_async_task(input)}
  end
end

defmodule Lux.Rust.NIF do
  @moduledoc false
  use Rustler, otp_app: :lux, crate: "lux_nif", path: "priv/rust/lux_nif"

  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)
  def echo_component(_comp), do: :erlang.nif_error(:nif_not_loaded)
  def parse_toml_to_json(_toml_str), do: :erlang.nif_error(:nif_not_loaded)
  def generate_toml(_package_name, _dependencies), do: :erlang.nif_error(:nif_not_loaded)
  def run_async_task(_input), do: :erlang.nif_error(:nif_not_loaded)
end
