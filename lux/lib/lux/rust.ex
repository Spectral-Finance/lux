defmodule Lux.Rust do
  @moduledoc """
  Provides functions for executing Rust code with variable bindings.

  The ~RS sigil is used to write Rust expressions directly in Elixir files.
  This integration uses NIFs (Native Implemented Functions) for high-performance
  native code execution.

  ## Examples

      iex> require Lux.Rust
      iex> Lux.Rust.rust variables: %{x: 40, y: 2} do
      ...>   ~RS"x + y"
      ...> end
      {:ok, 42}

  ## Performance

  Rust NIFs provide near-native performance for compute-intensive tasks.
  However, be aware that long-running NIFs can block the BEAM scheduler.
  For operations that may take more than 1ms, consider using dirty schedulers.
  """

  @type eval_option ::
          {:variables, map()}
          | {:timeout, pos_integer()}

  @type eval_options :: [eval_option()]

  @module_path Application.app_dir(:lux, "priv/rust")

  @doc """
  Evaluates a Rust expression with optional variable bindings.

  ## Options

    * `:variables` - A map of variables to bind in the Rust context

  ## Examples

      iex> Lux.Rust.eval("x * 2", variables: %{x: 21})
      {:ok, 42}

      iex> Lux.Rust.eval("x + y", variables: %{x: 10, y: 5})
      {:ok, 15}
  """
  @spec eval(String.t(), eval_options()) :: {:ok, term()} | {:error, term()}
  def eval(code, opts \\ []) do
    variables = Keyword.get(opts, :variables, %{})

    # Convert atom keys to string keys for Rust
    variables =
      variables
      |> Enum.map(fn
        {k, v} when is_atom(k) -> {Atom.to_string(k), v}
        {k, v} -> {k, v}
      end)
      |> Map.new()

    case Lux.Rust.Native.eval(code, variables) do
      {:error, _} = error -> error
      result -> {:ok, result}
    end
  rescue
    e in ArgumentError ->
      {:error, "Rust evaluation error: #{Exception.message(e)}"}

    e in ErlangError ->
      {:error, "Rust NIF error: #{inspect(e)}"}
  end

  @doc """
  Same as `eval/2` but raises on error.

  ## Examples

      iex> Lux.Rust.eval!("x + y", variables: %{x: 1, y: 2})
      3

      iex> Lux.Rust.eval!("undefined_var")
      ** (RuntimeError) Rust error: Variable not found: undefined_var
  """
  @spec eval!(String.t(), eval_options()) :: term() | no_return()
  def eval!(code, opts \\ []) do
    case eval(code, opts) do
      {:ok, result} -> result
      {:error, error} -> raise RuntimeError, "Rust error: #{inspect(error)}"
    end
  end

  @doc """
  Converts an Elixir term to a JSON string using Rust's serde_json.

  ## Examples

      iex> Lux.Rust.to_json(%{name: "test", count: 42})
      {:ok, ~s({"count":42,"name":"test"})}
  """
  @spec to_json(term()) :: {:ok, String.t()} | {:error, term()}
  def to_json(value) do
    case Lux.Rust.Native.to_json(value) do
      {:error, _} = error -> error
      result -> {:ok, result}
    end
  rescue
    e -> {:error, "JSON serialization error: #{Exception.message(e)}"}
  end

  @doc """
  Parses a JSON string into an Elixir term using Rust's serde_json.

  ## Examples

      iex> Lux.Rust.from_json(~s({"name":"test","count":42}))
      {:ok, %{"name" => "test", "count" => 42}}
  """
  @spec from_json(String.t()) :: {:ok, term()} | {:error, term()}
  def from_json(json) do
    case Lux.Rust.Native.from_json(json) do
      {:error, _} = error -> error
      result -> {:ok, result}
    end
  rescue
    e -> {:error, "JSON parsing error: #{Exception.message(e)}"}
  end

  @doc """
  Returns the version of the Rust integration.

  ## Examples

      iex> Lux.Rust.version()
      "0.1.0"
  """
  @spec version() :: String.t()
  def version do
    Lux.Rust.Native.version()
  rescue
    _ -> "unknown"
  end

  @doc """
  Performs a health check to verify the Rust NIF is loaded correctly.

  ## Examples

      iex> Lux.Rust.health_check()
      {:ok, %{"status" => "ok", "version" => "0.1.0", "language" => "rust"}}
  """
  @spec health_check() :: {:ok, map()} | {:error, term()}
  def health_check do
    case Lux.Rust.Native.health_check() do
      {:error, _} = error -> error
      result -> {:ok, result}
    end
  rescue
    e -> {:error, "Health check failed: #{Exception.message(e)}"}
  end

  @doc """
  Returns the module path for Rust source files.
  """
  @spec module_path() :: String.t()
  def module_path, do: @module_path

  @doc """
  A macro that enables writing Rust expressions directly in Elixir with variable bindings.
  Rust expressions must be wrapped in ~RS sigil.

  ## Options
    * `:variables` - A map of variables to bind in the Rust context

  ## Examples

      iex> require Lux.Rust
      iex> Lux.Rust.rust variables: %{x: 40, y: 2} do
      ...>   ~RS"x + y"
      ...> end
      {:ok, 42}

      iex> require Lux.Rust
      iex> Lux.Rust.rust do
      ...>   ~RS"10 * 5"
      ...> end
      {:ok, 50}
  """
  defmacro rust(opts \\ [], do: {:sigil_RS, _, [{:<<>>, _, [code]}, []]}) do
    quote do
      variables = Keyword.get(unquote(opts), :variables, %{})
      Lux.Rust.eval(unquote(code), variables: variables)
    end
  end

  @doc false
  defmacro sigil_RS({:<<>>, _meta, [string]}, _modifiers) do
    quote do: unquote(string)
  end
end

defmodule Lux.Rust.Native do
  @moduledoc false
  # Native NIF functions - these are replaced by the Rust implementations at load time

  @on_load :load_nif

  @doc false
  def load_nif do
    base_path = :code.priv_dir(:lux)

    # Determine library extension based on OS
    ext =
      case :os.type() do
        {:unix, :darwin} -> "dylib"
        {:unix, _} -> "so"
        {:win32, _} -> "dll"
      end

    # Try release first, then debug
    paths = [
      Path.join([base_path, "rust/target/release/liblux_rust.#{ext}"]),
      Path.join([base_path, "rust/target/release/liblux_rust"]),
      Path.join([base_path, "rust/target/debug/liblux_rust.#{ext}"]),
      Path.join([base_path, "rust/target/debug/liblux_rust"])
    ]

    result =
      Enum.find_value(paths, :not_found, fn path ->
        case :erlang.load_nif(to_charlist(path), 0) do
          :ok -> :ok
          {:error, {:reload, _}} -> :ok
          _ -> nil
        end
      end)

    case result do
      :ok -> :ok
      :not_found -> :ok  # Allow graceful degradation when NIF not built
    end
  end

  def eval(_code, _variables), do: :erlang.nif_error(:nif_not_loaded)
  def to_json(_value), do: :erlang.nif_error(:nif_not_loaded)
  def from_json(_json), do: :erlang.nif_error(:nif_not_loaded)
  def version, do: :erlang.nif_error(:nif_not_loaded)
  def health_check, do: :erlang.nif_error(:nif_not_loaded)
end
