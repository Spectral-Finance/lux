defmodule Mix.Tasks.Python.TestTest do
  use UnitCase, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Python.Test, as: PythonTest

  @python_dir Path.join(File.cwd!(), "priv/python")

  setup do
    # Store original PATH
    original_path = System.get_env("PATH")

    on_exit(fn ->
      # Restore original PATH
      System.put_env("PATH", original_path)
    end)

    %{original_path: original_path}
  end

  describe "run/1" do
    test "raises when poetry is not found" do
      System.put_env("PATH", "/nonexistent")

      assert_raise Mix.Error, ~r/Poetry not found/, fn ->
        capture_io(fn -> PythonTest.run([]) end)
      end
    end

    test "installs dependencies when poetry.lock is missing", %{original_path: original_path} do
      # Ensure we have a mock poetry in PATH
      tmp_dir = System.tmp_dir()
      mock_poetry = Path.join(tmp_dir, "poetry")

      File.write!(mock_poetry, """
      #!/bin/sh
      echo "Mock poetry $1"
      exit 0
      """)

      File.chmod!(mock_poetry, 0o755)

      System.put_env("PATH", "#{tmp_dir}:#{original_path}")

      # Backup existing poetry.lock if it exists
      lock_file = Path.join(@python_dir, "poetry.lock")
      lock_backup = Path.join(@python_dir, "poetry.lock.backup")

      lock_existed =
        if File.exists?(lock_file) do
          File.rename!(lock_file, lock_backup)
          true
        else
          false
        end

      output =
        capture_io(fn ->
          PythonTest.run([])
        end)

      assert output =~ "Installing Python dependencies"

      # Restore poetry.lock if it existed
      if lock_existed do
        File.rename!(lock_backup, lock_file)
      end

      # Cleanup
      File.rm(mock_poetry)
    end

    test "handles pytest arguments correctly", %{original_path: original_path} do
      # Create a mock poetry that verifies the pytest arguments
      tmp_dir = System.tmp_dir()
      mock_poetry = Path.join(tmp_dir, "poetry")

      File.write!(mock_poetry, """
      #!/bin/sh
      if [ "$1" = "run" ] && [ "$2" = "pytest" ] && [ "$3" = "--marker=slow" ]; then
        echo "Correct pytest args received"
        exit 0
      else
        echo "Incorrect args: $@"
        exit 1
      fi
      """)

      File.chmod!(mock_poetry, 0o755)

      System.put_env("PATH", "#{tmp_dir}:#{original_path}")

      # Ensure poetry.lock exists to skip installation
      lock_file = Path.join(@python_dir, "poetry.lock")
      File.touch!(lock_file)

      output =
        capture_io(fn ->
          PythonTest.run(["--marker=slow"])
        end)

      assert output =~ "Correct pytest args received"

      # Cleanup
      File.rm(mock_poetry)
      File.rm(lock_file)
    end

    test "handles pytest failures gracefully", %{original_path: original_path} do
      # Create a mock poetry that simulates a test failure
      tmp_dir = System.tmp_dir()
      mock_poetry = Path.join(tmp_dir, "poetry")

      File.write!(mock_poetry, """
      #!/bin/sh
      echo "Tests failed"
      exit 1
      """)

      File.chmod!(mock_poetry, 0o755)

      System.put_env("PATH", "#{tmp_dir}:#{original_path}")

      # Ensure poetry.lock exists to skip installation
      lock_file = Path.join(@python_dir, "poetry.lock")
      File.touch!(lock_file)

      assert_raise Mix.Error, ~r/Python tests failed/, fn ->
        capture_io(fn -> PythonTest.run([]) end)
      end

      # Cleanup
      File.rm(mock_poetry)
      File.rm(lock_file)
    end
  end
end
