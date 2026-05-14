defmodule Lux.Rust.TestFixtures do
  @moduledoc """
  Helpers for creating temporary Rust projects in Lux tests.
  """

  @doc """
  Creates a temporary Rust library project with one passing test.
  """
  @spec create_temp_project(keyword()) :: {:ok, String.t()}
  def create_temp_project(opts \\ []) do
    prefix = Keyword.get(opts, :prefix, "lux_rust_test")
    project_path = Path.join(System.tmp_dir!(), "#{prefix}_#{System.unique_integer([:positive])}")

    File.mkdir_p!(Path.join(project_path, "src"))

    File.write!(Path.join(project_path, "Cargo.toml"), """
    [package]
    name = "lux_rust_test_fixture"
    version = "0.1.0"
    edition = "2021"

    [lib]
    path = "src/lib.rs"
    """)

    File.write!(Path.join(project_path, "src/lib.rs"), """
    pub fn add(left: u64, right: u64) -> u64 {
        left + right
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        #[test]
        fn adds_two_numbers() {
            assert_eq!(add(2, 2), 4);
        }
    }
    """)

    {:ok, project_path}
  end

  @doc """
  Creates a temporary project, yields its path, and removes it afterwards.
  """
  @spec with_temp_project((String.t() -> term()), keyword()) :: term()
  def with_temp_project(callback, opts \\ []) when is_function(callback, 1) do
    {:ok, path} = create_temp_project(opts)

    try do
      callback.(path)
    after
      File.rm_rf!(path)
    end
  end
end
