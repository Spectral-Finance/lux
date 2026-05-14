defmodule Lux.Rust.TestRunnerTest do
  use UnitCase, async: true

  alias Lux.Rust.TestRunner

  describe "build_test_plan/2" do
    test "builds cargo args with filters, runner flags, and coverage env" do
      plan =
        TestRunner.build_test_plan("/tmp/lux-rust",
          filter: "fixture_ready",
          features: "serde,ffi",
          jobs: 2,
          no_capture: true,
          coverage: true
        )

      assert plan.command == "cargo"

      assert plan.args == [
               "test",
               "--features",
               "serde,ffi",
               "--jobs",
               "2",
               "fixture_ready",
               "--",
               "--nocapture"
             ]

      assert plan.env["CARGO_INCREMENTAL"] == "0"
      assert plan.env["RUSTFLAGS"] == "-Cinstrument-coverage"
      assert plan.coverage.enabled
    end
  end

  describe "parse_test_output/1" do
    test "summarizes cargo output and failed test names" do
      output = """
      running 2 tests
      test tests::passes ... ok
      test tests::fails ... FAILED

      failures:
          tests::fails

      test result: FAILED. 1 passed; 1 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.01s
      """

      summary = TestRunner.parse_test_output(output)

      assert summary.status == :failed
      assert summary.passed == 1
      assert summary.failed == 1
      assert summary.failures == ["tests::fails"]
    end

    test "sums multiple cargo test binaries" do
      output = """
      test result: ok. 2 passed; 0 failed; 1 ignored; 0 measured; 0 filtered out; finished in 0.01s
      test result: ok. 3 passed; 0 failed; 0 ignored; 0 measured; 1 filtered out; finished in 0.01s
      """

      summary = TestRunner.parse_test_output(output)

      assert summary.status == :ok
      assert summary.passed == 5
      assert summary.ignored == 1
      assert summary.filtered_out == 1
    end
  end

  describe "run/2" do
    test "runs through an injected runner" do
      root = tmp_dir()

      File.write!(
        Path.join(root, "Cargo.toml"),
        "[package]\nname = \"x\"\nversion = \"0.1.0\"\nedition = \"2021\"\n"
      )

      runner = fn _command, _args, _opts ->
        {"test result: ok. 2 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.01s",
         0}
      end

      assert {:ok, summary} =
               TestRunner.run(root, runner: runner, require_toolchain: false, project_root: root)

      assert summary.status == :ok
      assert summary.passed == 2
      assert summary.exit_status == 0
    end

    test "reports a missing manifest" do
      root = tmp_dir()

      assert {:error, summary} =
               TestRunner.run(root, runner: fn _, _, _ -> {"", 0} end, require_toolchain: false)

      assert summary.status == :missing_manifest
    end
  end

  describe "parse_lcov/1" do
    test "parses aggregate line and branch coverage" do
      lcov = """
      TN:
      SF:src/lib.rs
      LF:4
      LH:3
      BRF:2
      BRH:1
      end_of_record
      """

      summary = TestRunner.parse_lcov(lcov)

      assert summary.lines_found == 4
      assert summary.lines_hit == 3
      assert summary.line_rate == 75.0
      assert summary.branch_rate == 50.0
      assert [%{source: "src/lib.rs"}] = summary.files
    end
  end

  defp tmp_dir do
    path = Path.join(System.tmp_dir!(), "lux-rust-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(path)
    path
  end
end
