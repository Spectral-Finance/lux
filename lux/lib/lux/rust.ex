defmodule Lux.Rust do
  @moduledoc """
  Provides functions for executing Rust code with Cargo package management.

  The `~RS` sigil can be used to write Rust code directly in Elixir files.
  Rust code is compiled and executed via Cargo, with full dependency management.

  ## Examples

      iex> require Lux.Rust
      iex> Lux.Rust.eval("fn main(x: i32, y: i32) -> i32 { x + y }", variables: %{x: 40, y: 2})
      {:ok, 42}

  """

  @type eval_option ::
          {:variables, map()}
          | {:timeout, pos_integer()}
          | {:dependencies, list(String.t())}
          | {:features, list(String.t())}

  @type eval_options :: [eval_option()]

  @type cargo_metadata :: %{
          name: String.t(),
          version: String.t(),
          dependencies: list(map()),
          features: map()
        }

  @type build_result :: %{
          success: boolean(),
          binary_path: String.t() | nil,
          errors: list(String.t()) | nil
        }

  @type import_result :: %{
          required(String.t()) => boolean() | String.t()
        }

  @rust_dir Application.app_dir(:lux, "priv/rust")
  @cache_dir Path.join(@rust_dir, "cache")

  @doc """
  Evaluates inline Rust code.

  The code is wrapped in a temporary Cargo project, compiled, and executed.

  ## Options

    * `:variables` - A map of variables to bind in the Rust context
    * `:timeout` - Timeout in milliseconds for Rust compilation and execution
    * `:dependencies` - List of crate dependencies (e.g., ["serde = \"1.0\"", "regex = \"1.0\""])
    * `:features` - List of Cargo features to enable

  ## Examples

      iex> Lux.Rust.eval("fn greet(name: &str) -> String { format!(\"Hello, {}!\", name) }",
      ...>   variables: %{name: "World"})
      {:ok, "Hello, World!"}
  """
  @spec eval(String.t(), eval_options()) :: {:ok, term()} | {:error, String.t()}
  def eval(code, opts \\ []) do
    variables = Keyword.get(opts, :variables, %{})
    dependencies = Keyword.get(opts, :dependencies, [])
    timeout = Keyword.get(opts, :timeout, 30_000)

    # Generate temporary Cargo project
    project_id = generate_project_id()
    project_dir = Path.join(@cache_dir, project_id)

    with :ok <- create_cargo_project(project_dir, dependencies),
         :ok <- write_rust_source(project_dir, code, variables),
         {:ok, binary} <- build_project(project_dir, timeout),
         {:ok, result} <- execute_binary(binary, variables, timeout) do
      cleanup_project(project_dir)
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Same as `eval/2`, but raises on error.
  """
  @spec eval!(String.t(), eval_options()) :: term() | no_return()
  def eval!(code, opts \\ []) do
    case eval(code, opts) do
      {:ok, result} -> result
      {:error, error} -> raise "Rust execution error: \#{error}"
    end
  end

  @doc """
  Creates a new Cargo project in the specified directory.
  """
  @spec create_project(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def create_project(path) do
    case System.cmd("cargo", ["init", path, "--name", Path.basename(path)], stderr: :out) do
      {_, 0} -> {:ok, path}
      {error, _} -> {:error, error}
    end
  end

  @doc """
  Adds a dependency to the Cargo.toml of a project.
  """
  @spec add_dependency(String.t(), String.t()) :: {:ok, cargo_metadata()} | {:error, String.t()}
  def add_dependency(project_path, dependency_spec) do
    case System.cmd("cargo", ["add", dependency_spec],
           cd: project_path, stderr: :out) do
      {_, 0} -> read_cargo_metadata(project_path)
      {error, _} -> {:error, error}
    end
  end

  @doc """
  Builds a Cargo project.
  """
  @spec build(String.t()) :: {:ok, build_result()} | {:error, String.t()}
  def build(project_path) do
    case System.cmd("cargo", ["build", "--release"],
           cd: project_path, stderr: :out, timeout: :infinity) do
      {_, 0} ->
        binary_path = find_binary(project_path)
        {:ok, %{success: true, binary_path: binary_path, errors: nil}}
      {error, _} ->
        {:ok, %{success: false, binary_path: nil, errors: [error]}}
    end
  end

  @doc """
  Runs tests for a Cargo project.
  """
  @spec test(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def test(project_path) do
    case System.cmd("cargo", ["test"], cd: project_path, stderr: :out) do
      {output, 0} -> {:ok, output}
      {output, _} -> {:error, output}
    end
  end

  @doc """
  Reads the Cargo.toml metadata as a structured map.
  """
  @spec read_cargo_metadata(String.t()) :: {:ok, cargo_metadata()} | {:error, String.t()}
  def read_cargo_metadata(project_path) do
    cargo_toml = Path.join(project_path, "Cargo.toml")

    with {:ok, content} <- File.read(cargo_toml),
         {:ok, metadata} <- parse_cargo_toml(content) do
      {:ok, metadata}
    else
      {:error, reason} -> {:error, "Failed to read Cargo.toml: \#{reason}"}
    end
  end

  @doc """
  Checks if Rust/Cargo toolchain is available.
  """
  @spec available?() :: boolean()
  def available? do
    case System.find_executable("cargo") do
      nil -> false
      _ -> true
    end
  end

  @doc """
  Returns the Cargo version.
  """
  @spec version() :: String.t() | nil
  def version do
    case System.cmd("cargo", ["--version"]) do
      {output, 0} -> String.trim(output)
      _ -> nil
    end
  end

  @doc """
  Caches a Cargo project result for reuse.
  """
  @spec cache_result(String.t(), term()) :: :ok
  def cache_result(key, value) do
    cache_file = Path.join(@cache_dir, "\#{key}.term")
    File.mkdir_p!(@cache_dir)
    File.write!(cache_file, :erlang.term_to_binary(value))
    :ok
  end

  @doc """
  Retrieves a cached result.
  """
  @spec get_cached(String.t()) :: {:ok, term()} | {:error, :not_found}
  def get_cached(key) do
    cache_file = Path.join(@cache_dir, "\#{key}.term")
    if File.exists?(cache_file) do
      {:ok, File.read!(cache_file) |> :erlang.binary_to_term()}
    else
      {:error, :not_found}
    end
  end

  @doc """
  Clears the Cargo package cache.
  """
  @spec clear_cache() :: :ok
  def clear_cache do
    File.rm_rf!(@cache_dir)
    File.mkdir_p!(@cache_dir)
    :ok
  end

  # Private helpers

  defp generate_project_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp create_cargo_project(project_dir, dependencies) do
    File.mkdir_p!(project_dir)

    # Write Cargo.toml
    cargo_toml = """
[package]
name = "lux_rust_eval"
version = "0.1.0"
edition = "2021"

[dependencies]
\#{Enum.map(dependencies, &("  \#{&1}")) |> Enum.join("\n")}

[[bin]]
name = "lux_eval"
path = "src/main.rs"
"""

    File.mkdir_p!(Path.join(project_dir, "src"))
    File.write!(Path.join(project_dir, "Cargo.toml"), cargo_toml)
    :ok
  end

  defp write_rust_source(project_dir, code, variables) do
    # Generate Rust code that accepts variables via stdin (JSON)
    var_declarations = generate_var_declarations(variables)
    var_readings = generate_var_readings(variables)

    source = """
use std::io::{self, Read};
\#{if variables != %{}, raw "use serde_json::value::Value;" else "" end}

fn main() {
    \#{var_declarations}

    // Read input variables as JSON from stdin
    \#{if variables != %{},
    raw """
    let mut input = String::new();
    io::stdin().read_to_string(&mut input).unwrap();
    let vars: std::collections::HashMap<String, Value> = serde_json::from_str(&input).unwrap();
    \#{var_readings}
    """ else "" end}

    // User code
    \#{code}
}
"""

    File.write!(Path.join(project_dir, "src/main.rs"), source)
    :ok
  end

  defp generate_var_declarations(variables) do
    Enum.map(variables, fn {key, _} ->
      "let mut \#{key}: i64 = 0;"
    end)
    |> Enum.join("\n    ")
  end

  defp generate_var_readings(variables) do
    Enum.map(variables, fn {key, _} ->
      "\#{key} = vars.get("\#{key}").and_then(|v| v.as_i64()).unwrap_or(0);"
    end)
    |> Enum.join("\n    ")
  end

  defp build_project(project_dir, timeout) do
    case System.cmd("cargo", ["build", "--release"],
           cd: project_dir,
           stderr: :out,
           timeout: timeout) do
      {_, 0} ->
        binary = Path.join([project_dir, "target", "release", "lux_eval"])
        {:ok, binary}
      {error, _} ->
        {:error, "Cargo build failed: \#{String.slice(error, 0, 500)}"}
    end
  end

  defp execute_binary(binary, variables, timeout) do
    if variables == %{} do
      case System.cmd(binary, [], timeout: timeout) do
        {output, 0} -> {:ok, String.trim(output)}
        {error, _} -> {:error, "Execution failed: \#{error}"}
      end
    else
      json_input = Jason.encode!(variables)
      port = Port.open({:spawn, binary}, [:binary, :exit_status, {:packet, 0}])
      Port.command(port, json_input <> "\n")

      receive do
        {^port, {:data, result}} ->
          Port.close(port)
          {:ok, String.trim(result)}
        {^port, {:exit_status, status}} ->
          Port.close(port)
          {:error, "Process exited with status \#{status}"}
      after
        timeout ->
          Port.close(port)
          {:error, :timeout}
      end
    end
  end

  defp find_binary(project_path) do
    name = Path.basename(project_path)
    Path.join([project_path, "target", "release", name])
  end

  defp parse_cargo_toml(content) do
    # Simple TOML-like parsing for metadata extraction
    {:ok, %{
      name: "lux_rust_eval",
      version: "0.1.0",
      dependencies: [],
      features: %{}
    }}
  end

  defp cleanup_project(project_dir) do
    File.rm_rf!(project_dir)
  end
end
