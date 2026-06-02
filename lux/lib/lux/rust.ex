defmodule Lux.Rust do
  @moduledoc """
  Provides functions for defining and running Rust components in Lux.

  The ~RS sigil is used to write Rust code directly in Elixir files,
  similar to how ~PY and ~JS sigils work for Python and Node.js.

  Rust code within ~RS sigils is compiled and executed via the native
  Rustler NIF interface for maximum performance.

  ## Component Definition

  Lux components (Prisms, Beams, Lenses) can be defined in Rust:

      defmodule MyApp.RustPrism do
        use Lux.Prism, name: "Rust Prism"

        require Lux.Rust

        def handler(input, _ctx) do
          Lux.Rust.execute(
            ~RS'''
            fn process_data(input: &str) -> String {
                format!("processed: {}", input)
            }
            ''',
            input
          )
        end
      end

  ## Examples

      iex> require Lux.Rust
      iex> Lux.Rust.eval(~RS'''
      ...> fn add(a: i64, b: i64) -> i64 { a + b }
      ...> ''', variables: %{a: 1, b: 2})
      {:ok, 3}
  """

  alias Lux.Native

  @rust_crate_path Path.expand("../../../priv/rust", __DIR__)

  @type eval_option ::
          {:variables, map()}
          | {:handler, String.t()}

  @type eval_options :: [eval_option()]

  @doc """
  Evaluates Rust code with optional variable bindings.

  ## Options

    * `:variables` - A map of variables to pass to the Rust code
    * `:handler` - Name of the handler function to call

  ## Examples

      iex> Lux.Rust.eval("fn add(a: i64, b: i64) -> i64 { a + b }", variables: %{a: 1, b: 2})
      {:ok, 3}
  """
  @spec eval(String.t(), eval_options()) :: {:ok, term()} | {:error, String.t()}
  def eval(code, opts \\ []) do
    variables = Keyword.get(opts, :variables, %{})
    handler = Keyword.get(opts, :handler, "main")

    if Native.loaded?() do
      try do
        result = Native.rust_eval(code, variables, handler)
        {:ok, result}
      rescue
        e in RuntimeError -> {:error, "Rust evaluation error: #{Exception.message(e)}"}
      end
    else
      {:error, "Rust native library not loaded"}
    end
  end

  @doc """
  Same as eval/2 but raises on error.
  """
  @spec eval!(String.t(), eval_options()) :: term() | no_return()
  def eval!(code, opts \\ []) do
    case eval(code, opts) do
      {:ok, result} -> result
      {:error, error} ->
        raise RuntimeError, "Rust error: #{error}"
    end
  end

  @doc """
  Returns the path to the Rust crate directory.
  """
  @spec rust_crate_path() :: String.t()
  def rust_crate_path, do: @rust_crate_path

  @doc """
  A macro for executing Rust code with variable bindings.
  Rust code should be wrapped in a sigil ~RS to bypass Elixir syntax checking.
  """
  defmacro rust(opts \\ [], do: {:sigil_RS, _, [{:<<>>, _, [code]}, []]}) do
    quote do
      variables = Keyword.get(unquote(opts), :variables, %{})
      handler = Keyword.get(unquote(opts), :handler, "main")

      eval_opts =
        []
        |> Keyword.put(:variables, variables)
        |> Keyword.put(:handler, handler)

      Lux.Rust.eval!(unquote(code), eval_opts)
    end
  end

  @doc false
  defmacro sigil_RS({:<<>>, _meta, [string]}, _modifiers) do
    quote do: unquote(string)
  end

  @doc """
  Executes a Rust component (Prism, Beam, Lens) by type and name.

  ## Examples

      Lux.Rust.execute_component("prism", [:my_prism, :handler], input)
  """
  @spec execute_component(String.t(), [atom()], term()) :: term()
  def execute_component(component_type, path, input) do
    cond do
      Native.loaded?() ->
        Native.rust_execute_component(component_type, path, input)

      true ->
        raise "Rust native library not loaded"
    end
  end

  @doc """
  Returns available Rust component types and counts.
  """
  @spec component_info() :: %{String.t() => non_neg_integer()}
  def component_info do
    if Native.loaded?() do
      Native.rust_component_info()
    else
      %{}
    end
  end

  @doc """
  Returns the Rust native library version info.
  """
  @spec version() :: {:ok, String.t()} | {:error, String.t()}
  def version do
    Native.version()
  end
end
