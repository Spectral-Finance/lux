defmodule Lux.Rust do
  @moduledoc """
  Provides functions for executing Rust code via NIFs (Native Implemented Functions).

  The Rust integration enables high-performance native code execution within Lux
  components. Unlike Python and Node.js integrations which use external processes,
  Rust code runs directly in the BEAM VM through Rustler NIFs, providing:

  - Zero-copy data transfer for binaries
  - Minimal latency for function calls
  - Direct memory sharing with Elixir
  - Full type safety via the Rustler type system

  ## Setup

  The Rust NIF must be compiled before use:

      cd priv/rust
      cargo build --release

  ## Examples

      # Execute a built-in function
      iex> Lux.Rust.execute("add", %{a: 40, b: 2})
      {:ok, 42}

      # Evaluate an expression with variables
      iex> Lux.Rust.eval("x + y", variables: %{x: 10, y: 5})
      {:ok, 15}

      # Check health status
      iex> Lux.Rust.health_check()
      {:ok, "healthy"}

  ## Built-in Functions

  The following functions are available out of the box:

  - `add` - Add two numbers: `%{a: number, b: number}`
  - `multiply` - Multiply two numbers: `%{a: number, b: number}`
  - `concat` - Concatenate two strings: `%{a: string, b: string}`
  - `hash_sha256` - Hash data with SHA256: `%{data: string | binary}`
  - `json_parse` - Parse JSON string: `%{json: string}`
  - `json_stringify` - Stringify value to JSON: `%{value: any}`

  ## Custom Functions

  To add custom Rust functions, modify `priv/rust/src/lib.rs` and add a new
  case to the `dispatch_function` match expression.
  """

  @type eval_option ::
          {:variables, map()}
          | {:timeout, pos_integer()}

  @type eval_options :: [eval_option()]

  @module_path Application.app_dir(:lux, "priv/rust")

  # Load the NIF when the module is loaded
  @on_load :load_nif

  @doc false
  def load_nif do
    nif_path = Path.join(@module_path, "target/release/liblux_rust")

    case :erlang.load_nif(String.to_charlist(nif_path), 0) do
      :ok ->
        :ok

      {:error, {:reload, _}} ->
        # NIF already loaded
        :ok

      {:error, reason} ->
        # Log warning but don't fail - allows graceful degradation
        require Logger

        Logger.warning(
          "Failed to load Rust NIF: #{inspect(reason)}. " <>
            "Rust functions will return {:error, :nif_not_loaded}. " <>
            "Run 'cargo build --release' in priv/rust to compile."
        )

        :ok
    end
  end

  @doc """
  Execute a named Rust function with the given arguments.

  This is the primary way to call Rust code from Elixir. Functions
  are dispatched by name and receive a map of arguments.

  ## Arguments

    * `func_name` - The name of the function to execute (string)
    * `args` - A map of arguments to pass to the function

  ## Returns

    * `{:ok, result}` - Success with the return value
    * `{:error, reason}` - Failure with error message

  ## Examples

      iex> Lux.Rust.execute("add", %{a: 1, b: 2})
      {:ok, 3}

      iex> Lux.Rust.execute("unknown_function", %{})
      {:error, "Unknown function: unknown_function"}
  """
  @spec execute(String.t(), map()) :: {:ok, term()} | {:error, String.t()}
  def execute(func_name, args \\ %{}) when is_binary(func_name) and is_map(args) do
    Lux.Rust.Native.execute(func_name, args)
  rescue
    e -> {:error, Exception.message(e)}
  end

  @doc """
  Same as `execute/2` but raises on error.

  ## Examples

      iex> Lux.Rust.execute!("add", %{a: 1, b: 2})
      3

      iex> Lux.Rust.execute!("unknown", %{})
      ** (RuntimeError) Unknown function: unknown
  """
  @spec execute!(String.t(), map()) :: term() | no_return()
  def execute!(func_name, args \\ %{}) do
    case execute(func_name, args) do
      {:ok, result} -> result
      {:error, error} -> raise RuntimeError, "Rust error: #{error}"
    end
  end

  @doc """
  Evaluate a simple expression with optional variable bindings.

  This function allows evaluating arithmetic and string expressions
  with runtime-specified variables.

  ## Options

    * `:variables` - A map of variables to bind in the evaluation context

  ## Supported Operations

    * Arithmetic: `+`, `-`, `*`, `/`
    * String concatenation: `+`
    * Variable references

  ## Examples

      iex> Lux.Rust.eval("x + y", variables: %{x: 10, y: 5})
      {:ok, 15}

      iex> Lux.Rust.eval("2 * 3")
      {:ok, 6}

      iex> Lux.Rust.eval("undefined_var")
      {:error, "Undefined variable: undefined_var"}
  """
  @spec eval(String.t(), eval_options()) :: {:ok, term()} | {:error, String.t()}
  def eval(expression, opts \\ []) when is_binary(expression) do
    variables = Keyword.get(opts, :variables, %{})
    Lux.Rust.Native.eval(expression, variables)
  rescue
    e -> {:error, Exception.message(e)}
  end

  @doc """
  Same as `eval/2` but raises on error.

  ## Examples

      iex> Lux.Rust.eval!("x * 2", variables: %{x: 21})
      42

      iex> Lux.Rust.eval!("undefined")
      ** (RuntimeError) Rust error: Undefined variable: undefined
  """
  @spec eval!(String.t(), eval_options()) :: term() | no_return()
  def eval!(expression, opts \\ []) do
    case eval(expression, opts) do
      {:ok, result} -> result
      {:error, error} -> raise RuntimeError, "Rust error: #{error}"
    end
  end

  @doc """
  Returns version information about the Rust integration.

  ## Examples

      iex> Lux.Rust.version()
      %{"version" => "0.1.0", "rustc" => "1.75.0", "target" => "x86_64-unknown-linux-gnu"}
  """
  @spec version() :: map()
  def version do
    Lux.Rust.Native.version()
  rescue
    _ -> %{"version" => "unknown", "rustc" => "unknown", "target" => "unknown"}
  end

  @doc """
  Check if the Rust NIF is properly loaded and functional.

  ## Examples

      iex> Lux.Rust.health_check()
      {:ok, "healthy"}
  """
  @spec health_check() :: {:ok, String.t()} | {:error, String.t()}
  def health_check do
    Lux.Rust.Native.health_check()
  rescue
    _ -> {:error, :nif_not_loaded}
  end

  @doc """
  Returns the path to the Rust module directory.
  """
  @spec module_path() :: String.t()
  def module_path, do: @module_path

  @doc """
  Check if the Rust NIF is available.

  Returns `true` if the NIF is loaded and functional, `false` otherwise.
  """
  @spec available?() :: boolean()
  def available? do
    case health_check() do
      {:ok, _} -> true
      _ -> false
    end
  end
end
