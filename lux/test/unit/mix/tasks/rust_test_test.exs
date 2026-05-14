defmodule Mix.Tasks.Rust.TestTest do
  use UnitCase, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Rust.Test, as: RustTest

  setup do
    original_path = System.get_env("PATH")

    on_exit(fn ->
      System.put_env("PATH", original_path || "")
      Mix.Task.reenable("rust.test")
    end)

    %{original_path: original_path || ""}
  end

  test "runs cargo tests from the selected project root", %{original_path: original_path} do
    root = cargo_project!()

    bin =
      mock_cargo!("""
      #!/bin/sh
      echo "test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.01s"
      exit 0
      """)

    System.put_env("PATH", "#{bin}:#{original_path}")

    output =
      capture_io(fn ->
        RustTest.run(["--project-root", root])
      end)

    assert output =~ "Rust tests ok: 1 passed"
  end

  test "raises on cargo failures", %{original_path: original_path} do
    root = cargo_project!()

    bin =
      mock_cargo!("""
      #!/bin/sh
      echo "test tests::fails ... FAILED"
      echo "test result: FAILED. 0 passed; 1 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.01s"
      exit 1
      """)

    System.put_env("PATH", "#{bin}:#{original_path}")

    assert_raise Mix.Error, ~r/Rust tests failed/, fn ->
      capture_io(fn -> RustTest.run(["--project-root", root]) end)
    end
  end

  defp cargo_project! do
    root = Path.join(System.tmp_dir!(), "lux-rust-task-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)

    File.write!(
      Path.join(root, "Cargo.toml"),
      "[package]\nname = \"x\"\nversion = \"0.1.0\"\nedition = \"2021\"\n"
    )

    root
  end

  defp mock_cargo!(script) do
    bin = Path.join(System.tmp_dir!(), "lux-rust-bin-#{System.unique_integer([:positive])}")
    File.mkdir_p!(bin)

    cargo = Path.join(bin, "cargo")
    File.write!(cargo, script)
    File.chmod!(cargo, 0o755)

    bin
  end
end
