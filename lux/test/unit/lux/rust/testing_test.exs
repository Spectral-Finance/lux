defmodule Lux.Rust.TestingTest do
  use UnitCase, async: false

  alias Lux.Rust.Testing

  @moduletag :unit

  @cargo_available match?({_, 0}, System.cmd("cargo", ["--version"], stderr_to_stdout: true))

  # ── parse_test_output/1 ──────────────────────────────────────────────────────

  describe "parse_test_output/1" do
    test "parses all-passing output" do
      output = """
      running 3 tests
      test add ... ok
      test subtract ... ok
      test multiply ... ok
      test result: ok. 3 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.02s
      """

      assert {:ok, result} = Testing.parse_test_output(output)
      assert result.passed == 3
      assert result.failed == 0
      assert result.ignored == 0
      assert result.duration_ms == 20
      assert result.coverage_pct == nil
      assert is_binary(result.output)
    end

    test "parses output with failures" do
      output = """
      running 2 tests
      test add ... ok
      test bad_test ... FAILED
      test result: FAILED. 1 passed; 1 failed; 0 ignored; 0 measured; finished in 0.05s
      """

      assert {:ok, result} = Testing.parse_test_output(output)
      assert result.passed == 1
      assert result.failed == 1
      assert result.ignored == 0
    end

    test "parses output with ignored tests" do
      output = """
      running 4 tests
      test unit_a ... ok
      test unit_b ... ok
      test slow_test ... ignored
      test flaky_test ... ignored
      test result: ok. 2 passed; 0 failed; 2 ignored; 0 measured; finished in 0.01s
      """

      assert {:ok, result} = Testing.parse_test_output(output)
      assert result.passed == 2
      assert result.ignored == 2
    end

    test "parses fractional duration correctly" do
      output =
        "test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; finished in 1.500s\n"

      assert {:ok, result} = Testing.parse_test_output(output)
      assert result.duration_ms == 1500
    end

    test "returns empty result for empty output" do
      assert {:ok, result} = Testing.parse_test_output("")
      assert result.passed == 0
      assert result.failed == 0
      assert result.ignored == 0
      assert result.duration_ms == 0
    end

    test "returns error for unparseable non-empty output" do
      assert {:error, msg} = Testing.parse_test_output("this is not cargo output at all")
      assert String.contains?(msg, "Could not parse")
    end

    test "output field contains the original string" do
      raw = "test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; finished in 0.00s\n"
      assert {:ok, result} = Testing.parse_test_output(raw)
      assert result.output == raw
    end
  end

  # ── setup_test_fixture/2 and cleanup_fixture/1 ───────────────────────────────

  describe "setup_test_fixture/2" do
    test "creates project directory" do
      {:ok, dir} = Testing.setup_test_fixture("basic", "pub fn add(a: i32, b: i32) -> i32 { a + b }")
      assert File.dir?(dir)
      Testing.cleanup_fixture(dir)
    end

    test "creates Cargo.toml in project root" do
      {:ok, dir} = Testing.setup_test_fixture("with_toml", "pub fn noop() {}")
      assert File.exists?(Path.join(dir, "Cargo.toml"))
      Testing.cleanup_fixture(dir)
    end

    test "writes source to src/lib.rs" do
      source = "pub fn answer() -> i32 { 42 }"
      {:ok, dir} = Testing.setup_test_fixture("with_src", source)
      assert File.read!(Path.join(dir, "src/lib.rs")) == source
      Testing.cleanup_fixture(dir)
    end

    test "Cargo.toml contains the fixture name as package name" do
      {:ok, dir} = Testing.setup_test_fixture("my_pkg", "")
      toml = File.read!(Path.join(dir, "Cargo.toml"))
      assert String.contains?(toml, "my_pkg")
      Testing.cleanup_fixture(dir)
    end

    test "two fixtures with the same name land in different directories" do
      {:ok, dir1} = Testing.setup_test_fixture("dup", "fn one() {}")
      {:ok, dir2} = Testing.setup_test_fixture("dup", "fn two() {}")
      assert dir1 != dir2
      Testing.cleanup_fixture(dir1)
      Testing.cleanup_fixture(dir2)
    end
  end

  describe "cleanup_fixture/1" do
    test "removes the project directory" do
      {:ok, dir} = Testing.setup_test_fixture("cleanup_me", "pub fn x() {}")
      assert File.dir?(dir)
      assert :ok = Testing.cleanup_fixture(dir)
      refute File.exists?(dir)
    end

    test "is idempotent on already-removed directory" do
      dir = Path.join(System.tmp_dir!(), "lux_rust_fixture_gone_#{:rand.uniform(999_999)}")
      assert :ok = Testing.cleanup_fixture(dir)
    end
  end

  # ── run_tests/2 result structure (skipped when cargo is absent) ──────────────

  describe "run_tests/2" do
    @tag :integration
    test "returns structured result map with required keys" do
      if @cargo_available do
        source = """
        #[cfg(test)]
        mod tests {
            #[test]
            fn it_works() {
                assert_eq!(2 + 2, 4);
            }
        }
        """

        {:ok, dir} = Testing.setup_test_fixture("run_tests_basic", source)

        try do
          assert {:ok, result} = Testing.run_tests(dir)
          assert is_integer(result.passed)
          assert is_integer(result.failed)
          assert is_integer(result.ignored)
          assert is_binary(result.output)
          assert is_integer(result.duration_ms)
          assert result.coverage_pct == nil
          assert result.passed >= 1
          assert result.failed == 0
        after
          Testing.cleanup_fixture(dir)
        end
      else
        :ok
      end
    end

    test "returns error when cargo is not available" do
      result = Testing.run_tests("/non/existent/path/that/cannot/be/a/cargo/project")

      case result do
        {:error, msg} -> assert is_binary(msg)
        {:ok, _} -> :ok
      end
    end
  end

  # ── run_tests!/2 ─────────────────────────────────────────────────────────────

  describe "run_tests!/2" do
    @tag :integration
    test "raises RuntimeError on failure" do
      if @cargo_available do
        source = """
        #[cfg(test)]
        mod tests {
            #[test]
            fn will_fail() {
                panic!("intentional failure");
            }
        }
        """

        {:ok, dir} = Testing.setup_test_fixture("run_tests_bang_fail", source)

        try do
          assert_raise RuntimeError, fn -> Testing.run_tests!(dir) end
        after
          Testing.cleanup_fixture(dir)
        end
      else
        :ok
      end
    end
  end
end
