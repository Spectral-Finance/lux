defmodule Lux.Lenses.Cargo.Lens do
  @moduledoc """
  Lens for managing Rust package dependencies via Cargo.

  Provides a unified interface to:
    - Read and parse Cargo.toml manifests
    - Add and remove dependencies
    - Run build commands (build, test, check)
    - Search crates.io

  ## Examples

      alias Lux.Lenses.Cargo.Lens, as: CargoLens

      # Read current manifest
      CargoLens.focus(%{action: "read_manifest"})

      # Add dependency
      CargoLens.focus(%{action: "add_dependency", name: "serde", version: "1.0"})

      # Remove dependency
      CargoLens.focus(%{action: "remove_dependency", name: "serde"})

      # Build
      CargoLens.focus(%{action: "build"})

      # Search crates
      CargoLens.focus(%{action: "search_crates", query: "serde"})
  """

  @type action ::
          :read_manifest
          | :write_manifest
          | :add_dependency
          | :remove_dependency
          | :build
          | :test
          | :check
          | :search_crates

  @doc """
  Focuses the lens by dispatching to the appropriate Cargo operation.

  ## Input Parameters

    * `action` - (required) One of: read_manifest, write_manifest, add_dependency,
      remove_dependency, build, test, check, search_crates
    * `name` - Dependency name (for add/remove)
    * `version` - Dependency version (for add)
    * `dep_type` - Dependency type: "normal", "dev", "build" (default: "normal")
    * `query` - Search query (for search_crates)
    * `manifest_path` - Custom path to Cargo.toml

  ## Returns

    * `{:ok, result}` on success
    * `{:error, reason}` on failure
  """
  @spec focus(map(), keyword()) :: {:ok, any()} | {:error, String.t()}
  def focus(input \\ %{}, _opts \\ []) do
    action = input[:action] |> to_string() |> String.to_existing_atom()

    case action do
      :read_manifest -> do_read_manifest(input)
      :write_manifest -> do_write_manifest(input)
      :add_dependency -> do_add_dependency(input)
      :remove_dependency -> do_remove_dependency(input)
      :build -> Lux.Rust.build()
      :test -> Lux.Rust.test()
      :check -> Lux.Rust.check()
      :search_crates -> Lux.Rust.search_crates(input[:query])
    end
  rescue
    ArgumentError ->
      {:error, "Unknown action: #{inspect(input[:action])}. Valid actions: read_manifest, write_manifest, add_dependency, remove_dependency, build, test, check, search_crates"}
  end

  defp do_read_manifest(input) do
    path = input[:manifest_path]
    Lux.Rust.read_manifest(path)
  end

  defp do_write_manifest(input) do
    manifest = input[:manifest]

    if manifest do
      path = input[:manifest_path]
      Lux.Rust.write_manifest(manifest, path)
    else
      {:error, "Missing :manifest key in input"}
    end
  end

  defp do_add_dependency(input) do
    name = input[:name]
    version = input[:version]

    unless name do
      {:error, "Missing :name for add_dependency"}
    else
      dep_type = (input[:dep_type] || "normal") |> String.to_existing_atom()
      opts = [type: dep_type]

      if version do
        Lux.Rust.add_dependency(name, version, opts)
      else
        {:error, "Missing :version for add_dependency"}
      end
    end
  end

  defp do_remove_dependency(input) do
    name = input[:name]

    unless name do
      {:error, "Missing :name for remove_dependency"}
    else
      dep_type = (input[:dep_type] || "normal") |> String.to_existing_atom()
      Lux.Rust.remove_dependency(name, type: dep_type)
    end
  end
end
