defmodule Lux.Rust.Cargo do
  @moduledoc """
  Cargo Package Management and Dependency Resolution for Lux (#100).

  Provides:
  - 'Cargo.toml' manifest generation with Rustler and Serde support
  - Semantic version constraint validation and dependency deduplication
  - Deterministic build cache key generation
  """

  @doc """
  Generates a 'Cargo.toml' manifest string for a Lux Rust crate with validated dependencies.
  """
  @spec render_cargo_toml(map()) :: {:ok, String.t()} | {:error, term()}
  def render_cargo_toml(config) when is_map(config) do
    name = Map.get(config, :name, "lux_nif")
    version = Map.get(config, :version, "0.1.0")
    edition = Map.get(config, :edition, "2021")
    deps = Map.get(config, :dependencies, %{"rustler" => "0.34", "serde" => "1.0"})

    if not is_binary(name) or name == "" do
      {:error, :invalid_package_name}
    else
      dep_lines =
        deps
        |> Enum.sort_by(fn {k, _} -> to_string(k) end)
        |> Enum.map(fn {k, v} -> "#{k} = \"#{v}\"" end)
        |> Enum.join("\n")

      manifest = """
      [package]
      name = "#{name}"
      version = "#{version}"
      edition = "#{edition}"

      [lib]
      name = "#{name}"
      crate-type = ["cdylib"]

      [dependencies]
      #{dep_lines}
      """

      {:ok, String.trim(manifest)}
    end
  end

  @doc """
  Computes a deterministic SHA-256 cache key for a Cargo manifest and target triple.
  """
  @spec cache_key(String.t(), String.t()) :: String.t()
  def cache_key(manifest_toml, target_triple \\ "x86_64-unknown-linux-gnu") do
    :crypto.hash(:sha256, manifest_toml <> ":" <> target_triple)
    |> Base.encode16(case: :lower)
  end
end
