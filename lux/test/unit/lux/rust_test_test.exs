defmodule Lux.RustTestTest do
  use UnitCase, async: true

  describe "default_dir/0" do
    test "returns default rust directory" do
      assert Lux.RustTest.default_dir() == "priv/rust"
    end
  end

  describe "project_path/1" do
    test "returns absolute path for project name" do
      path = Lux.RustTest.project_path("lux_rust_testing")
      assert String.ends_with?(path, "lux_rust_testing")
      assert String.contains?(path, "priv/rust")
    end
  end

  describe "list_projects/0" do
    test "returns list of Rust projects" do
      {:ok, projects} = Lux.RustTest.list_projects()
      assert is_list(projects)
    end
  end

  describe "run/1" do
    test "returns result structure" do
      result = Lux.RustTest.run!(path: "priv/rust/lux_rust_testing")
      assert is_map(result)
      assert result.passed >= 0
      assert result.failed >= 0
      assert result.total >= 0
    end
  end

  describe "summary/1" do
    test "generates summary string" do
      summary = Lux.RustTest.summary(%{passed: 3, failed: 1, total: 4})
      assert summary =~ "Rust tests:"
      assert summary =~ "3 passed"
      assert summary =~ "1 failed"
      assert summary =~ "4 total"
    end
  end
end
