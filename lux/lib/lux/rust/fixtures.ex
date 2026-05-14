defmodule Lux.Rust.Fixtures do
  @moduledoc """
  Fixture helpers for Elixir/Rust tests.

  Fixtures are ordinary files with a generated manifest that records byte sizes
  and SHA-256 hashes. Rust tests can read the same files while Elixir tests keep
  deterministic evidence of what was written.
  """

  @doc """
  Builds a manifest for fixture files.
  """
  @spec manifest(map() | keyword(), keyword()) :: map()
  def manifest(fixtures, opts \\ []) do
    generated_at = Keyword.get_lazy(opts, :generated_at, fn -> DateTime.utc_now() end)

    files =
      fixtures
      |> Enum.map(fn {path, content} ->
        content = to_string(content)

        %{
          path: safe_relative_path!(path),
          bytes: byte_size(content),
          sha256: :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
        }
      end)
      |> Enum.sort_by(& &1.path)

    %{
      format: 1,
      generated_at: DateTime.to_iso8601(generated_at),
      files: files,
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Writes fixture files into `root`.
  """
  @spec write_files!(Path.t(), map() | keyword()) :: [String.t()]
  def write_files!(root, fixtures) do
    root = Path.expand(root)
    File.mkdir_p!(root)

    Enum.map(fixtures, fn {path, content} ->
      relative_path = safe_relative_path!(path)
      destination = Path.join(root, relative_path)

      File.mkdir_p!(Path.dirname(destination))
      File.write!(destination, to_string(content))

      destination
    end)
  end

  @doc """
  Writes fixture files and a `lux_rust_fixtures.json` manifest.
  """
  @spec write_manifest!(Path.t(), map() | keyword(), keyword()) :: map()
  def write_manifest!(root, fixtures, opts \\ []) do
    write_files!(root, fixtures)
    manifest = manifest(fixtures, opts)

    manifest_path =
      Path.join(Path.expand(root), Keyword.get(opts, :manifest_name, "lux_rust_fixtures.json"))

    File.write!(manifest_path, Jason.encode!(manifest, pretty: true))
    Map.put(manifest, :manifest_path, manifest_path)
  end

  @doc """
  Creates a minimal Cargo project for tests or examples.
  """
  @spec create_project!(Path.t(), keyword()) :: String.t()
  def create_project!(root, opts \\ []) do
    root = Path.expand(root)
    name = Keyword.get(opts, :name, "lux_rust_fixture")
    edition = Keyword.get(opts, :edition, "2021")

    fixtures = %{
      "Cargo.toml" => cargo_toml(name, edition, Keyword.get(opts, :dependencies, [])),
      "src/lib.rs" => Keyword.get(opts, :lib_rs, default_lib_rs())
    }

    write_files!(root, fixtures)
    root
  end

  defp cargo_toml(name, edition, dependencies) do
    dependency_lines =
      dependencies
      |> Enum.map(fn {dependency, version} -> "#{dependency} = #{inspect(version)}" end)
      |> Enum.join("\n")

    """
    [package]
    name = "#{name}"
    version = "0.1.0"
    edition = "#{edition}"

    [dependencies]
    #{dependency_lines}
    """
  end

  defp default_lib_rs do
    """
    pub fn lux_fixture_ready() -> bool {
        true
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        #[test]
        fn fixture_ready() {
            assert!(lux_fixture_ready());
        }
    }
    """
  end

  defp safe_relative_path!(path) do
    path = to_string(path)
    parts = Path.split(path)

    cond do
      path == "" ->
        raise ArgumentError, "fixture path cannot be empty"

      Path.type(path) != :relative ->
        raise ArgumentError, "fixture path must be relative"

      Enum.any?(parts, &(&1 == "..")) ->
        raise ArgumentError, "fixture path cannot contain .."

      true ->
        Path.join(parts)
    end
  end
end
