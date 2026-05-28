```diff
--- a/lux/mix.exs
+++ b/lux/mix.exs
@@ -1,4 +1,6 @@
 defmodule Lux.MixProject do
+  @moduledoc false
+
   use Mix.Project
 
   def project do
@@ -15,7 +17,8 @@ defmodule Lux.MixProject do
         "coveralls.html": :test,
         "coveralls.json": :test,
         "coveralls.post": :test,
-        "coveralls.xml": :test
+        "coveralls.xml": :test,
+        "rust.test": :test
       ],
       test_coverage: [tool: ExCoveralls],
       preferred_cli_env: [
@@ -24,7 +27,8 @@ defmodule Lux.MixProject do
         coveralls: :test,
         "coveralls.html": :test,
         "coveralls.json": :test,
-        "coveralls.xml": :test
+        "coveralls.xml": :test,
+        "rust.test": :test
       ],
       docs: [
         main: "readme",
@@ -55,6 +59,7 @@ defmodule Lux.MixProject do
       {:ex_doc, "~> 0.31", only: :dev, runtime: false},
       {:excoveralls, "~> 0.18", only: :test},
       {:mimic, "~> 1.7", only: :test},
+      {:rustler, "~> 0.32.0", runtime: false},
 
       # Code quality
       {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
@@ -64,7 +69,8 @@ defmodule Lux.MixProject do
       # Data validation
       {:nimble_options, "~> 1.1"},
       {:jason, "~> 1.4"},
-      {:ex_json_schema, "~> 0.10.2"}
+      {:ex_json_schema, "~> 0.10.2"},
+      {:toml, "~> 0.7", runtime: false}
     ]
   end
 
@@ -77,7 +83,8 @@ defmodule Lux.MixProject do
         "hex.audit",
         "deps.unlock --check-unused",
         "compile --warnings-as-errors",
-        "test"
+        "test",
+        "rust.test"
       ],
       "hex.audit": ["cmd mix hex.audit || true"]
     ]
--- /dev/null
+++ b/lux/lib/lux/rust/testing.ex
@@ -0,0 +1,218 @@
+defmodule Lux.Rust.Testing do
+  @moduledoc """
+  Testing framework for Rust code in Lux.
+
+  Provides utilities for running Rust tests, integrating with `mix test`,
+  and cross-language test helpers.
+
+  ## Examples
+
+      # Run all Rust tests
+      Lux.Rust.Testing.run_tests()
+
+      # Run tests with coverage
+      Lux.Rust.Testing.run_tests(coverage: true)
+
+      # Run tests for a specific crate
+      Lux.Rust.Testing.run_tests(crate: "my_crate")
+
+  """
+
+  require Logger
+
+  @typedoc "Options for running Rust tests"
+  @type test_options :: [
+          coverage: boolean(),
+          crate: String.t() | nil,
+          features: String.t() | nil,
+          target: String.t() | nil,
+          verbose: boolean()
+        ]
+
+  @doc """
+  Runs Rust tests using cargo.
+
+  ## Options
+
+    * `:coverage` - Enable coverage reporting (default: false)
+    * `:crate` - Run tests for a specific crate (default: nil)
+    * `:features` - Comma-separated list of features to enable (default: nil)
+    * `:target` - Target triple for cross-compilation (default: nil)
+    * `:verbose` - Enable verbose output (default: false)
+
+  ## Examples
+
+      iex> Lux.Rust.Testing.run_tests()
+      :ok
+
+      iex> Lux.Rust.Testing.run_tests(coverage: true)
+      :ok
+
+  """
+  @spec run_tests(test_options()) :: :ok | {:error, term()}
+  def run_tests(opts \\ []) do
+    cmd = build_cargo_command(opts)
+    env = build_env(opts)
+
+    Logger.info("Running Rust tests with: #{Enum.join(cmd, " ")}")
+
+    case System.cmd("cargo", tl(cmd),
+           env: env,
+           into: IO.stream(:stdio, :line),
+           stderr_to_stdout: true,
+           cd: rust_project_path()
+         ) do
+      {_, 0} ->
+        :ok
+
+      {_, exit_code} ->
+        {:error, "Rust tests failed with exit code #{exit_code}"}
+    end
+  end
+
+  @doc """
+  Runs Rust tests and returns the result as a structured map.
+  Useful for programmatic test result processing.
+
+  ## Examples
+
+      iex> Lux.Rust.Testing.run_tests_json()
+      {:ok, %{passed: 10, failed: 0, ignored: 2, duration_ms: 1500}}
+
+  """
+  @spec run_tests_json(test_options()) :: {:ok, map()} | {:error, term()}
+  def run_tests_json(opts \\ []) do
+    cmd = build_cargo_command([:json | opts])
+    env = [{"RUST_TEST_FORMAT", "json"} | build_env(opts)]
+
+    case System.cmd("cargo", tl(cmd),
+           env: env,
+           stderr_to_stdout: true,
+           cd: rust_project_path()
+         ) do
+      {output, 0} ->
+        {:ok, parse_test_output(output)}
+
+      {output, _} ->
+        {:error, parse_test_output(output)}
+    end
+  end
+
+  @doc """
+  Checks if the Rust toolchain is installed and available.
+
+  ## Examples
+
+      iex> Lux.Rust.Testing.rust_available?()
+      true
+
+  """
+  @spec rust_available?() :: boolean()
+  def rust_available? do
+    match?({_, 0}, System.cmd("cargo", ["--version"], stderr_to_stdout: true))
+  end
+
+  @doc """
+  Returns the path to the Rust project directory.
+
+  ## Examples
+
+      iex> Lux.Rust.Testing.rust_project_path()
+      "/path/to/lux/native"
+
+  """
+  @spec rust_project_path() :: String.t()
+  def rust_project_path do
+    Application.get_env(:lux, :rust_project_path,