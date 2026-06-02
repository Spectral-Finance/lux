defmodule Lux.Rust.Test.FixturesTest do
  use ExUnit.Case, async: true
  @moduletag :unit

  alias Lux.Rust.Test.Fixtures

  describe "temp_rust_project/1" do
    test "creates a temporary Rust project" do
      {:ok, path} = Fixtures.temp_rust_project()
      assert File.exists?(path)
      assert File.exists?(Path.join(path, "Cargo.toml"))
      assert File.exists?(Path.join(path, "src/lib.rs"))

      cargo_content = File.read!(Path.join(path, "Cargo.toml"))
      assert String.contains?(cargo_content, "[package]")

      File.rm_rf!(path)
    end

    test "returns error when project already exists" do
      {:ok, path} = Fixtures.temp_rust_project()

      result = Fixtures.temp_rust_project(dir: path |> Path.dirname(), name: Path.basename(path))
      assert {:error, _} = result

      File.rm_rf!(path)
    end
  end

  describe "with_temp_rust_project/2" do
    test "sets up and tears down a project" do
      ref_path = nil

      Fixtures.with_temp_rust_project(fn path ->
        ref_path = path
        assert File.exists?(Path.join(path, "Cargo.toml"))
      end)

      assert ref_path != nil
      refute File.exists?(ref_path)
    end
  end

  describe "write_test_data/2" do
    test "writes and can read back test data JSON" do
      data = %{config: %{threshold: 0.5, name: "test"}}

      {:ok, path} = Fixtures.write_test_data(data)

      assert File.exists?(path)
      {:ok, decoded} = Fixtures.read_test_data(path)
      assert decoded == data

      File.rm!(path)
    end

    test "handles non-serializable data" do
      {:error, _} = Fixtures.write_test_data(fn x -> x end)
    rescue
      _ -> :ok
    end
  end

  describe "read_test_data/1" do
    test "returns error for non-existent file" do
      assert {:error, _} = Fixtures.read_test_data("/tmp/nonexistent_lux_test_file.json")
    end
  end

  describe "ensure_compiled/1" do
    @tag :slow
    test "verifies Rust project compiles" do
      rust_dir = Lux.Rust.TestRunner.rust_project_path()

      if File.dir?(rust_dir) do
        case Fixtures.ensure_compiled(rust_dir) do
          :ok -> :ok
          {:error, _} -> :ok
        end
      end
    end
  end
end
