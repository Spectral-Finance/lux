defmodule Lux.Rust.Cargo do
  @moduledoc """
  Cargo package management, dependency resolution, and crate cache integration for Lux (#100).
  """

  @doc """
  Generates a deterministic `Cargo.toml` manifest string given package metadata and dependency specs.
  """
  def generate_cargo_toml(pkg, deps) when is_map(pkg) and is_map(deps) do
    name = Map.fetch!(pkg, :name)
    version = Map.get(pkg, :version, "0.1.0")
    edition = Map.get(pkg, :edition, "2021")

    dep_lines =
      deps
      |> Enum.sort_by(fn {k, _} -> to_string(k) end)
      |> Enum.map(fn
        {k, v} when is_binary(v) ->
          "#{k} = \"#{v}\""

        {k, %{version: ver, features: feats}} ->
          feat_str = Enum.map_join(feats, ", ", &"\"#{&1}\"")
          "#{k} = { version = \"#{ver}\", features = [#{feat_str}] }"
      end)
      |> Enum.join("\n")

    """
    [package]
    name = "#{name}"
    version = "#{version}"
    edition = "#{edition}"

    [dependencies]
    #{dep_lines}
    """
  end

  @doc """
  Computes a deterministic SHA-256 cache key for a Cargo manifest + lockfile pair to avoid redundant rebuilds.
  """
  def compute_cache_key(cargo_toml, cargo_lock \\ "") when is_binary(cargo_toml) do
    :crypto.hash(:sha256, cargo_toml <> "\n---\n" <> cargo_lock)
    |> Base.encode16(case: :lower)
  end
end
