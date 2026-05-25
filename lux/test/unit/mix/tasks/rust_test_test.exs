defmodule Mix.Tasks.Rust.TestTest do
  use UnitCase, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Rust.Test, as: RustTest

  @rust_dir Path.join(File.cwd!(), "priv/rust")

  setup do
    original_path = System.get_env("PATH")

    on_exit(fn ->
      System.put_env("PATH", original_path)
    end)

    %{original_path: original_path}
  end

  describe "run/1" do
    test "raises a helpful error when cargo is not found" do
      System.put_env("PATH", "/nonexistent")

      assert_raise Mix.Error, ~r/Cargo not found/, fn ->
        capture_io(fn -> RustTest.run([]) end)
      end
    end

    test "raises when the priv/rust workspace is missing" do
      # Run from a temp dir that has no priv/rust/ directory.
      tmp_dir = Path.join(System.tmp_dir!(), "rust_test_no_workspace_#{System.unique_integer([:positive])}")
      File.mkdir_p!(tmp_dir)

      original_cwd = File.cwd!()
      File.cd!(tmp_dir)

      try do
        assert_raise Mix.Error, ~r/Rust workspace not found/, fn ->
          capture_io(fn -> RustTest.run([]) end)
        end
      after
        File.cd!(original_cwd)
        File.rm_rf!(tmp_dir)
      end
    end

    test "invokes cargo test --workspace by default", %{original_path: original_path} do
      tmp_dir = System.tmp_dir!()
      mock_cargo = Path.join(tmp_dir, "cargo")

      File.write!(mock_cargo, """
      #!/bin/sh
      if [ "$1" = "test" ] && [ "$2" = "--workspace" ] && [ -z "$3" ]; then
        echo "Cargo invoked with expected default args"
        exit 0
      else
        echo "Unexpected args: $@"
        exit 1
      fi
      """)

      File.chmod!(mock_cargo, 0o755)
      System.put_env("PATH", "#{tmp_dir}:#{original_path}")

      output =
        capture_io(fn ->
          RustTest.run([])
        end)

      assert output =~ "Cargo invoked with expected default args"

      File.rm(mock_cargo)
    end

    test "forwards extra arguments to cargo verbatim", %{original_path: original_path} do
      tmp_dir = System.tmp_dir!()
      mock_cargo = Path.join(tmp_dir, "cargo")

      File.write!(mock_cargo, """
      #!/bin/sh
      if [ "$1" = "test" ] && [ "$2" = "--workspace" ] && [ "$3" = "--release" ] && [ "$4" = "some::filter" ]; then
        echo "Forwarded args received correctly"
        exit 0
      else
        echo "Unexpected args: $@"
        exit 1
      fi
      """)

      File.chmod!(mock_cargo, 0o755)
      System.put_env("PATH", "#{tmp_dir}:#{original_path}")

      output =
        capture_io(fn ->
          RustTest.run(["--release", "some::filter"])
        end)

      assert output =~ "Forwarded args received correctly"

      File.rm(mock_cargo)
    end

    test "raises when cargo exits with non-zero status", %{original_path: original_path} do
      tmp_dir = System.tmp_dir!()
      mock_cargo = Path.join(tmp_dir, "cargo")

      File.write!(mock_cargo, """
      #!/bin/sh
      echo "Pretend rust tests failed"
      exit 1
      """)

      File.chmod!(mock_cargo, 0o755)
      System.put_env("PATH", "#{tmp_dir}:#{original_path}")

      assert_raise Mix.Error, ~r/Rust tests failed/, fn ->
        capture_io(fn -> RustTest.run([]) end)
      end

      File.rm(mock_cargo)
    end

    test "workspace directory exists at the expected location" do
      # Sanity check: the rest of the suite assumes priv/rust/ is part of
      # the repo. If this assertion fails the bounty's scaffolding has been
      # removed and the mix task tests above would silently misbehave.
      assert File.dir?(@rust_dir), "expected priv/rust/ workspace to exist"
      assert File.exists?(Path.join(@rust_dir, "Cargo.toml"))
      assert File.exists?(Path.join(@rust_dir, "lux_core/Cargo.toml"))
    end
  end
end
