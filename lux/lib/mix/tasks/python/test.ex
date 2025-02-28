defmodule Mix.Tasks.Python.Test do
  @shortdoc "Runs Python tests"
  @moduledoc """
  Runs Python tests using pytest.

  ## Examples

      # Run all Python tests
      mix python.test

      # Run specific test file
      mix python.test tests/test_eval.py

      # Run tests with specific marker
      mix python.test --marker="not slow"

      # Show test coverage
      mix python.test --cov

  The task will use Poetry to manage dependencies and run tests.
  Make sure you have Poetry installed and have run `poetry install`
  in the priv/python directory first.
  """

  use Mix.Task

  @requirements ["app.start"]

  defp safe_cmd(cmd, args, opts) do
    System.cmd(cmd, args, opts)
  rescue
    e in ErlangError ->
      case e do
        %ErlangError{original: :enoent} -> {:error, :not_found}
        _ -> reraise e, __STACKTRACE__
      end
  end

  @impl Mix.Task
  def run(args) do
    python_dir = Path.join(File.cwd!(), "priv/python")

    # Check if Poetry is installed
    case safe_cmd("which", ["poetry"], stderr_to_stdout: true) do
      {:error, :not_found} ->
        Mix.raise("""
        Poetry not found. Please install Poetry first:

            curl -sSL https://install.python-poetry.org | python3 -

        Then run `poetry install` in the priv/python directory.
        """)

      {_, 0} ->
        # Poetry is installed, proceed with running tests
        run_tests(python_dir, args)

      {_, _} ->
        Mix.raise("""
        Poetry not found. Please install Poetry first:

            curl -sSL https://install.python-poetry.org | python3 -

        Then run `poetry install` in the priv/python directory.
        """)
    end
  end

  defp run_tests(python_dir, args) do
    # Install dependencies if poetry.lock doesn't exist
    if !File.exists?(Path.join(python_dir, "poetry.lock")) do
      Mix.shell().info("Installing Python dependencies...")

      case safe_cmd("poetry", ["install"], cd: python_dir, stderr_to_stdout: true) do
        {:error, :not_found} ->
          Mix.raise("Failed to execute Poetry command")

        {output, 0} ->
          Mix.shell().info(output)

        {output, _} ->
          Mix.raise("Failed to install Python dependencies:\n\n#{output}")
      end
    end

    # Build the pytest command with any additional arguments
    pytest_args =
      case args do
        [] -> ["run", "pytest"]
        args -> ["run", "pytest"] ++ args
      end

    # Run the tests
    case safe_cmd("poetry", pytest_args,
           cd: python_dir,
           stderr_to_stdout: true,
           into: IO.stream()
         ) do
      {:error, :not_found} ->
        Mix.raise("Failed to execute Poetry command")

      {_, 0} ->
        :ok

      {_, status} ->
        Mix.raise("Python tests failed with status #{status}")
    end
  end
end
