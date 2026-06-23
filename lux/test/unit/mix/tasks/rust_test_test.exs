defmodule Mix.Tasks.Rust.TestTest do
  use UnitCase, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Rust.Test, as: RustTest

  describe "run/1" do
    test "raises when cargo is not found" do
      original_path = System.get_env("PATH")

      System.put_env("PATH", "/nonexistent")

      assert_raise Mix.Error, ~r/Cargo not found/, fn ->
        capture_io(fn -> RustTest.run(["--project", "lux_rust_testing"]) end)
      end

      System.put_env("PATH", original_path)
    end

    test "runs tests with project flag" do
      output =
        capture_io(fn ->
          RustTest.run(["--project", "lux_rust_testing"])
        end)

      assert output =~ "Running Rust tests"
    end

    test "accepts verbose flag" do
      output =
        capture_io(fn ->
          RustTest.run(["--project", "lux_rust_testing", "--verbose"])
        end)

      assert output =~ "Running Rust tests"
    end
  end
end
