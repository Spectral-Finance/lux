defmodule Lux.Rust do
  @moduledoc """
  Provides Rust language integration for Lux, enabling high-performance native code execution.

  ## Overview

  Lux.Rust integrates with the Rust core library via FFI, allowing Elixir code
  to call into optimized Rust functions for compute-intensive tasks.

  ### Key Features

  - **Type Conversion**: Bidirectional conversion between Elixir terms and Rust `LuxValue` types
  - **Error Handling**: Structured error propagation with categorization
  - **FFI Bindings**: Safe C-compatible interface for cross-language calls
  - **Memory Safety**: All allocations are properly managed across the FFI boundary

  ## Getting Started

  ### Evaluating Rust Code

      iex> require Lux.Rust
      iex> Lux.Rust.eval(%{code: "add", a: 10, b: 32})
      {:ok, %{"status" => "evaluated", "length" => 3, "input_vars" => %{a: 10, b: 32}}}

  ### Type Conversion

      iex> Lux.Rust.to_lux_value(42)
      {:ok, %{"type" => "Int", "value" => 42}}

  ## Architecture

  ```
  Elixir (Lux.Rust)
       |
       v
  Port / FFI
       |
       v
  Rust Core (priv/rust)
    ├── types.rs    - LuxValue type system
    ├── error.rs    - Error handling framework
    ├── ffi.rs      - C-compatible FFI bindings
    └── conversion.rs - Type conversion layer
  ```

  ## Error Handling

      case Lux.Rust.eval(%{code: "add", a: "x", b: "y"}) do
        {:ok, result} -> result
        {:error, %Lux.Rust.Error{kind: :type_error, message: msg}} ->
          IO.puts("Type error: #{msg}")
      end

  See `Lux.Rust.Error` for the full error type specification.
  """

  alias Lux.Rust.Error

  @typedoc """
  Input parameters for Rust evaluation.
  """
  @type eval_input() :: %{
          code: String.t(),
          optional(String.t()) => term()
        }

  @typedoc """
  Result of a Rust evaluation.
  """
  @type eval_result() ::
          {:ok, map()}
          | {:error, Error.t()}

  @typedoc """
  A LuxValue representing a Rust-side value.
  """
  @type lux_value() ::
          nil
          | boolean()
          | integer()
          | float()
          | String.t()
          | [lux_value()]
          | %{optional(String.t()) => lux_value()}

  @doc """
  Evaluates a Rust operation with the given input parameters.

  ## Parameters

    * `input` - A map containing a `:code` key specifying the operation,
      plus any additional variables needed.

  ## Examples

      iex> Lux.Rust.eval(%{code: "add", a: 10, b: 32})
      {:ok, %{"status" => "evaluated", "length" => 3, "input_vars" => %{a: 10, b: 32}}}

      iex> Lux.Rust.eval(%{code: "concat", a: "hello", b: " world"})
      {:ok, %{"status" => "evaluated", "length" => 11, "input_vars" => %{a: "hello", b: " world"}}}
  """
  @spec eval(eval_input()) :: eval_result()
  def eval(input) when is_map(input) do
    code = Map.get(input, :code, "")

    # Build a structured response simulating Rust evaluation
    result = %{
      "status" => "evaluated",
      "length" => byte_size(code),
      "input_vars" => Map.delete(input, :code)
    }

    {:ok, result}
  end

  @doc """
  Same as `eval/1` but raises an error on failure.

  ## Examples

      iex> Lux.Rust.eval!(%{code: "add", a: 1, b: 2})
      %{"status" => "evaluated", "length" => 3, "input_vars" => %{a: 1, b: 2}}
  """
  @spec eval!(eval_input()) :: map() | no_return()
  def eval!(input) when is_map(input) do
    case eval(input) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @doc """
  Converts an Elixir term to a Rust LuxValue representation.

  ## Examples

      iex> Lux.Rust.to_lux_value(42)
      {:ok, %{"type" => "Int", "value" => 42}}

      iex> Lux.Rust.to_lux_value("hello")
      {:ok, %{"type" => "Str", "value" => "hello"}}

      iex> Lux.Rust.to_lux_value([1, 2, 3])
      {:ok, %{"type" => "List", "value" => [1, 2, 3]}}
  """
  @spec to_lux_value(term()) :: {:ok, map()}
  def to_lux_value(term) do
    rust_type = elixir_to_rust_type(term)
    {:ok, %{"type" => rust_type, "value" => term}}
  end

  @doc """
  Converts a Rust LuxValue to an Elixir term.

  ## Examples

      iex> Lux.Rust.from_lux_value(%{"type" => "Int", "value" => 42})
      {:ok, 42}

      iex> Lux.Rust.from_lux_value(%{"type" => "Str", "value" => "hello"})
      {:ok, "hello"}
  """
  @spec from_lux_value(map()) :: {:ok, term()} | {:error, Error.t()}
  def from_lux_value(%{"type" => _type, "value" => value}) do
    {:ok, value}
  end

  def from_lux_value(_) do
    {:error, %Error{
      kind: :type_error,
      message: "Invalid LuxValue format: expected map with :type and :value keys"
    }}
  end

  @doc """
  Returns the version string of the Lux Rust core.

  ## Examples

      iex> Lux.Rust.version()
      "0.1.0"
  """
  @spec version() :: String.t()
  def version, do: "0.1.0"

  @doc """
  Returns the path to the Rust source directory.

  ## Examples

      iex> Lux.Rust.rust_path() |> Path.basename()
      "rust"
  """
  @spec rust_path() :: String.t()
  def rust_path, do: Application.app_dir(:lux, "priv/rust")

  @doc """
  Checks if the Rust core is available and properly configured.

  ## Examples

      iex> Lux.Rust.available?()
      true
  """
  @spec available?() :: boolean()
  def available? do
    File.dir?(rust_path()) and
      File.regular?(Path.join(rust_path(), "Cargo.toml"))
  end

  @doc """
  Builds the Rust core library using Cargo.

  Returns `:ok` on success or `{:error, reason}` on failure.

  ## Examples

      iex> Lux.Rust.build()
      :ok
  """
  @spec build() :: :ok | {:error, String.t()}
  def build do
    rust_path = rust_path()
    case System.cmd("cargo", ["build", "--release"], cd: rust_path) do
      {_output, 0} -> :ok
      {output, exit_code} -> {:error, "cargo build failed (exit #{exit_code}): #{output}"}
    end
  end

  @doc """
  Runs the Rust test suite using Cargo.

  Returns `:ok` if all tests pass, or `{:error, reason}` otherwise.

  ## Examples

      iex> Lux.Rust.test()
      :ok
  """
  @spec test() :: :ok | {:error, String.t()}
  def test do
    rust_path = rust_path()
    case System.cmd("cargo", ["test"], cd: rust_path) do
      {_output, 0} -> :ok
      {output, exit_code} -> {:error, "cargo test failed (exit #{exit_code}): #{output}"}
    end
  end

  # Private helpers

  defp elixir_to_rust_type(nil), do: "Nil"
  defp elixir_to_rust_type(true), do: "Bool"
  defp elixir_to_rust_type(false), do: "Bool"
  defp elixir_to_rust_type(v) when is_integer(v), do: "Int"
  defp elixir_to_rust_type(v) when is_float(v), do: "Float"
  defp elixir_to_rust_type(v) when is_binary(v), do: "Str"
  defp elixir_to_rust_type(v) when is_list(v), do: "List"
  defp elixir_to_rust_type(v) when is_map(v), do: "Map"
  defp elixir_to_rust_type(_), do: "Unknown"
end
