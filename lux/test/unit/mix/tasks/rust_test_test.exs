defmodule Mix.Tasks.Rust.TestTest do
  use UnitCase, async: false

  import ExUnit.CaptureIO

  alias Lux.Rust.TestRunner
  alias Mix.Tasks.Rust.Test, as: RustTest

  setup do
    original_path = System.get_env("PATH")

    on_exit(fn ->
      System.put_env("PATH", original_path)
    end)

    %{original_path: original_path}
  end

  describe "Mix.Tasks.Rust.Test.run/1" do
    test "raises when cargo is not found" do
      System.put_env("PATH", "/nonexistent")

      assert_raise Mix.Error, ~r/Cargo not found/, fn ->
        capture_io(fn -> RustTest.run([]) end)
      end
    end

    test "forwards test and coverage arguments to cargo", %{original_path: original_path} do
      tmp_dir = System.tmp_dir!()
      mock_cargo = Path.join(tmp_dir, "cargo")

      File.write!(mock_cargo, """
      #!/bin/sh
      echo "Cargo invoked with: $@"
      exit 0
      """)

      File.chmod!(mock_cargo, 0o755)
      System.put_env("PATH", "#{tmp_dir}:#{original_path}")

      out =
        capture_io(fn ->
          RustTest.run(["--cov"])
        end)

      assert out =~ "Cargo invoked with: tarpaulin --out Stdout"
      File.rm(mock_cargo)
    end
  end

  describe "Lux.Rust.TestRunner cross-language utilities and coverage parser" do
    test "creates and loads shared JSON fixtures and verifies cross-language parity" do
      {:ok, fixture} = TestRunner.create_fixture(:pool_tvl, %{"soroswap" => 250, "blend" => 750})
      assert {:ok, loaded} = TestRunner.load_fixture(:pool_tvl)
      assert loaded.json =~ "soroswap"

      assert {:ok, %{matched: true, elixir_output: 1000, rust_output: 1000}} =
               TestRunner.assert_cross_language_parity(
                 fn m -> {:ok, m["soroswap"] + m["blend"]} end,
                 fn m -> {:ok, Map.values(m) |> Enum.sum()} end,
                 fixture.payload
               )
    end

    test "parses cargo test and coverage stdout metrics" do
      sample_output = """
      running 4 tests
      test result: ok. 4 passed; 0 failed; 1 ignored; 0 measured; 0 filtered out
      94.50% coverage, 38/40 lines covered
      """

      report = TestRunner.parse_test_and_coverage_output(sample_output)
      assert report.passed == 4
      assert report.failed == 0
      assert report.ignored == 1
      assert report.coverage_percent == 94.5
      assert report.status == :ok
    end
  end
end
