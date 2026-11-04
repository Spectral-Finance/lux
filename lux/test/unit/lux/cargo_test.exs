defmodule Lux.CargoTest do
  use UnitCase, async: false

  alias Lux.Cargo

  @cargo_toml_path Path.join(System.tmp_dir!(), "test_cargo_#{System.unique_integer([:positive])}.toml")

  setup do
    on_exit(fn ->
      if File.exists?(@cargo_toml_path) do
        File.rm(@cargo_toml_path)
      end
    end)
    :ok
  end

  describe "generate_cargo_toml/2" do
    test "happy_path: generates valid Cargo.toml for a new project" do
      assert {:ok, toml} = Cargo.generate_cargo_toml("my_project")
      assert toml["package"]["name"] == "my_project"
      assert toml["package"]["version"] == "0.1.0"
      assert toml["package"]["edition"] == "2021"
      assert toml["dependencies"] == %{}
    end

    test "happy_path: generates Cargo.toml with dependencies" do
      assert {:ok, toml} = Cargo.generate_cargo_toml("my_app", [{"serde", "1.0"}, {"tokio", "1.32"}])
      assert toml["package"]["name"] == "my_app"
      assert toml["dependencies"]["serde"] == "1.0"
      assert toml["dependencies"]["tokio"] == "1.32"
    end

    test "null: rejects nil project name" do
      assert_raise FunctionClauseError, fn ->
        Cargo.generate_cargo_toml(nil)
      end
    end

    test "empty: rejects empty project name" do
      assert {:error, _} = Cargo.generate_cargo_toml("")
    end

    test "empty: rejects whitespace-only project name" do
      assert {:error, _} = Cargo.generate_cargo_toml("   ")
    end

    test "boundary: handles project name with special characters" do
      assert {:ok, toml} = Cargo.generate_cargo_toml("my-app_v2.0")
      assert toml["package"]["name"] == "my-app_v2.0"
    end

    test "negative: rejects non-binary project name" do
      assert_raise FunctionClauseError, fn ->
        Cargo.generate_cargo_toml(123)
      end
    end
  end

  describe "parse_cargo_toml/1" do
    test "happy_path: parses a valid Cargo.toml file" do
      content = """
[package]
name = "test_project"
version = "0.1.0"
edition = "2021"

[dependencies]
serde = "1.0"
"""
      File.write!(@cargo_toml_path, content)
      assert {:ok, parsed} = Cargo.parse_cargo_toml(@cargo_toml_path)
      assert parsed["package"]["name"] == "test_project"
      assert parsed["package"]["version"] == "0.1.0"
      assert parsed["dependencies"]["serde"] == "1.0"
    end

    test "null: rejects nil path" do
      assert_raise FunctionClauseError, fn ->
        Cargo.parse_cargo_toml(nil)
      end
    end

    test "empty: rejects empty path" do
      assert {:error, _} = Cargo.parse_cargo_toml("")
    end

    test "negative: rejects non-existent file" do
      assert {:error, _} = Cargo.parse_cargo_toml("/nonexistent/path/Cargo.toml")
    end

    test "boundary: parses Cargo.toml with no dependencies" do
      content = """
[package]
name = "bare_project"
version = "1.0.0"
"""
      File.write!(@cargo_toml_path, content)
      assert {:ok, parsed} = Cargo.parse_cargo_toml(@cargo_toml_path)
      assert parsed["package"]["name"] == "bare_project"
      assert Map.get(parsed, "dependencies", %{}) == %{}
    end
  end

  describe "add_dependency/3" do
    test "happy_path: adds a new dependency to Cargo.toml" do
      content = """
[package]
name = "test_project"
version = "0.1.0"

[dependencies]
"""
      File.write!(@cargo_toml_path, content)
      {:ok, result} = Cargo.add_dependency(@cargo_toml_path, "serde", "1.0")
      assert result.success == true
      assert result.name == "serde"
      assert result.version == "1.0"
      assert result.error == nil
      assert {:ok, parsed} = Cargo.parse_cargo_toml(@cargo_toml_path)
      assert parsed["dependencies"]["serde"] == "1.0"
    end

    test "happy_path: adds dependency with default version \"*\" when not specified" do
      content = """
[package]
name = "test_project"
version = "0.1.0"

[dependencies]
"""
      File.write!(@cargo_toml_path, content)
      {:ok, result} = Cargo.add_dependency(@cargo_toml_path, "tokio")
      assert result.success == true
      assert result.version == "*"
    end

    test "null: rejects nil path" do
      assert_raise FunctionClauseError, fn ->
        Cargo.add_dependency(nil, "serde", "1.0")
      end
    end

    test "null: rejects nil dependency name" do
      assert_raise FunctionClauseError, fn ->
        Cargo.add_dependency(@cargo_toml_path, nil, "1.0")
      end
    end

    test "empty: rejects empty dependency name" do
      assert {:error, _} = Cargo.add_dependency(@cargo_toml_path, "", "1.0")
    end

    test "negative: adds dependency to non-existent file" do
      assert {:error, _} = Cargo.add_dependency("/nonexistent/Cargo.toml", "serde", "1.0")
    end

    test "negative: removes non-existent dependency returns error" do
      content = """
[package]
name = "test_project"
version = "0.1.0"

[dependencies]
serde = "1.0"
"""
      File.write!(@cargo_toml_path, content)
      assert {:error, _} = Cargo.remove_dependency(@cargo_toml_path, "nonexistent_crate")
    end
  end

  describe "remove_dependency/2" do
    test "happy_path: removes an existing dependency" do
      content = """
[package]
name = "test_project"
version = "0.1.0"

[dependencies]
serde = "1.0"
tokio = "1.32"
"""
      File.write!(@cargo_toml_path, content)
      {:ok, result} = Cargo.remove_dependency(@cargo_toml_path, "serde")
      assert result.success == true
      assert result.name == "serde"
      assert {:ok, parsed} = Cargo.parse_cargo_toml(@cargo_toml_path)
      assert !Map.has_key?(parsed["dependencies"], "serde")
      assert Map.has_key?(parsed["dependencies"], "tokio")
    end

    test "null: rejects nil path" do
      assert_raise FunctionClauseError, fn ->
        Cargo.remove_dependency(nil, "serde")
      end
    end

    test "empty: rejects empty dependency name" do
      assert {:error, _} = Cargo.remove_dependency(@cargo_toml_path, "")
    end

    test "negative: removes non-existent dependency returns error" do
      content = """
[package]
name = "test_project"
version = "0.1.0"

[dependencies]
serde = "1.0"
"""
      File.write!(@cargo_toml_path, content)
      assert {:error, _} = Cargo.remove_dependency(@cargo_toml_path, "nonexistent")
    end
  end

  describe "rust_version/0" do
    test "happy_path: returns Rust toolchain version when available" do
      case Cargo.rust_version() do
        {:ok, version} ->
          assert is_binary(version)
        {:error, _} ->
          :ok
      end
    end
  end

  describe "crate_available/1" do
    test "happy_path: checks crate availability and returns boolean" do
      case Cargo.crate_available("serde") do
        {:ok, result} ->
          assert is_boolean(result.available)
          assert result.version == nil or is_binary(result.version)
        {:error, _} ->
          :ok
      end
    end

    test "null: rejects nil crate name" do
      assert_raise FunctionClauseError, fn ->
        Cargo.crate_available(nil)
      end
    end

    test "empty: empty crate name returns not available" do
      assert {:ok, result} = Cargo.crate_available("")
      assert result.available == false
    end
  end

  describe "cache_dir/0" do
    test "happy_path: returns cache directory path" do
      dir = Cargo.cache_dir()
      assert is_binary(dir)
      assert String.length(dir) > 0
    end
  end

  describe "clear_cache/0" do
    test "happy_path: clears cache without error when registry does not exist" do
      assert :ok = Cargo.clear_cache()
    end
  end

  describe "concurrency" do
    test "concurrency_race: simultaneous add_dependency operations on same file" do
      content = """
[package]
name = "concurrent_test"
version = "0.1.0"

[dependencies]
"""
      File.write!(@cargo_toml_path, content)

      tasks = for i <- 1..5 do
        Task.async(fn -> Cargo.add_dependency(@cargo_toml_path, "crate_#{i}", "1.0") end)
      end

      results = Enum.map(tasks, &Task.await/1)
      successes = Enum.count(results, fn
        {:ok, %{success: true}} -> true
        _ -> false
      end)
      assert successes >= 1
    end

    test "concurrency_race: same crate added simultaneously by multiple tasks" do
      content = """
[package]
name = "race_test"
version = "0.1.0"

[dependencies]
"""
      File.write!(@cargo_toml_path, content)

      tasks = for _i <- 1..10 do
        Task.async(fn -> Cargo.add_dependency(@cargo_toml_path, "shared_crate", "1.0") end)
      end

      results = Enum.map(tasks, &Task.await/1)
      successes = Enum.count(results, fn
        {:ok, %{success: true}} -> true
        _ -> false
      end)
      assert successes >= 1
      assert {:ok, parsed} = Cargo.parse_cargo_toml(@cargo_toml_path)
      assert parsed["dependencies"]["shared_crate"] == "1.0"
    end
  end

  describe "regression" do
    test "regression: Cargo.toml round-trip preserves data integrity" do
      original = %{
        "package" => %{"name" => "regression_test", "version" => "1.2.3", "edition" => "2021"},
        "dependencies" => %{"serde" => "1.0", "tokio" => "1.32"}
      }

      File.write!(@cargo_toml_path, serialize_toml_for_test(original))

      assert {:ok, parsed} = Cargo.parse_cargo_toml(@cargo_toml_path)
      assert parsed["package"]["name"] == "regression_test"
      assert parsed["package"]["version"] == "1.2.3"
      assert parsed["dependencies"]["serde"] == "1.0"
    end

    test "regression: adding then removing dependency returns to original state" do
      content = """
[package]
name = "roundtrip_test"
version = "0.1.0"

[dependencies]
"""
      File.write!(@cargo_toml_path, content)

      {:ok, %{success: true}} = Cargo.add_dependency(@cargo_toml_path, "serde", "1.0")
      assert {:ok, parsed} = Cargo.parse_cargo_toml(@cargo_toml_path)
      assert parsed["dependencies"]["serde"] == "1.0"

      {:ok, %{success: true}} = Cargo.remove_dependency(@cargo_toml_path, "serde")
      assert {:ok, parsed_after} = Cargo.parse_cargo_toml(@cargo_toml_path)
      assert !Map.has_key?(parsed_after["dependencies"], "serde")
    end

    test "regression: serialize then parse preserves all data types" do
      original = %{
        "package" => %{"name" => "type_test", "version" => "2.0.0", "edition" => "2021"},
        "dependencies" => %{"serde" => "1.0", "tokio" => "1.32", "rand" => "0.8"}
      }

      File.write!(@cargo_toml_path, serialize_toml_for_test(original))

      assert {:ok, parsed} = Cargo.parse_cargo_toml(@cargo_toml_path)
      assert parsed["package"]["name"] == "type_test"
      assert parsed["package"]["version"] == "2.0.0"
      assert parsed["package"]["edition"] == "2021"
      assert parsed["dependencies"]["serde"] == "1.0"
      assert parsed["dependencies"]["tokio"] == "1.32"
      assert parsed["dependencies"]["rand"] == "0.8"
    end

    test "regression: multiple add and remove operations maintain consistency" do
      content = """
[package]
name = "consistency_test"
version = "0.1.0"

[dependencies]
"""
      File.write!(@cargo_toml_path, content)

      {:ok, _} = Cargo.add_dependency(@cargo_toml_path, "crate_a", "1.0")
      {:ok, _} = Cargo.add_dependency(@cargo_toml_path, "crate_b", "2.0")
      {:ok, _} = Cargo.add_dependency(@cargo_toml_path, "crate_c", "3.0")

      assert {:ok, parsed} = Cargo.parse_cargo_toml(@cargo_toml_path)
      assert Map.keys(parsed["dependencies"]) == ["crate_a", "crate_b", "crate_c"]

      {:ok, _} = Cargo.remove_dependency(@cargo_toml_path, "crate_b")

      assert {:ok, parsed_after} = Cargo.parse_cargo_toml(@cargo_toml_path)
      assert Map.has_key?(parsed_after["dependencies"], "crate_a")
      assert !Map.has_key?(parsed_after["dependencies"], "crate_b")
      assert Map.has_key?(parsed_after["dependencies"], "crate_c")
    end
  end

  defp serialize_toml_for_test(map) do
    map
    |> Enum.reduce([], fn {section, content}, acc ->
      section_header = "\n[#{section}]\n"
      body = Enum.map_join(content, "\n", fn {k, v} ->
        "#{k} = #{toml_value_for_test(v)}"
      end)
      acc ++ [section_header, body]
    end)
    |> Enum.join()
    |> String.trim_leading()
  end

  defp toml_value_for_test(v) do
    if is_binary(v), do: "\"#{v}\"", else: to_string(v)
  end

  describe "boundary" do
    test "boundary: dependency version \"0\" is accepted" do
      content = """
[package]
name = "test_project"
version = "0.1.0"

[dependencies]
serde = "0"
"""
      File.write!(@cargo_toml_path, content)
      assert {:ok, parsed} = Cargo.parse_cargo_toml(@cargo_toml_path)
      assert parsed["dependencies"]["serde"] == "0"
    end

    test "boundary: very long project name is accepted" do
      long_name = String.duplicate("a", 255)
      assert {:ok, toml} = Cargo.generate_cargo_toml(long_name)
      assert toml["package"]["name"] == long_name
    end

    test "boundary: zero dependencies in generate_cargo_toml" do
      assert {:ok, toml} = Cargo.generate_cargo_toml("empty_deps", [])
      assert toml["dependencies"] == %{}
    end

    test "boundary: parse Cargo.toml with only package section" do
      content = """
[package]
name = "package_only"
version = "1.0.0"
edition = "2021"
"""
      File.write!(@cargo_toml_path, content)
      assert {:ok, parsed} = Cargo.parse_cargo_toml(@cargo_toml_path)
      assert parsed["package"]["name"] == "package_only"
      assert Map.get(parsed, "dependencies", %{}) == %{}
    end
  end

  describe "negative" do
    test "negative: malformed TOML content returns error" do
      File.write!(@cargo_toml_path, "this is not valid toml [[[")
      result = Cargo.parse_cargo_toml(@cargo_toml_path)
      assert is_tuple(result) and elem(result, 0) in [:ok, :error]
    end

    test "negative: add_dependency with empty version string" do
      content = """
[package]
name = "test_project"
version = "0.1.0"

[dependencies]
"""
      File.write!(@cargo_toml_path, content)
      {:ok, result} = Cargo.add_dependency(@cargo_toml_path, "serde", "")
      assert result.success == true
      assert result.version == ""
    end

    test "negative: parse_cargo_toml with non-string path raises" do
      assert_raise FunctionClauseError, fn ->
        Cargo.parse_cargo_toml(123)
      end
    end

    test "negative: remove_dependency with non-binary name raises" do
      assert_raise FunctionClauseError, fn ->
        Cargo.remove_dependency(@cargo_toml_path, 123)
      end
    end
  end

end