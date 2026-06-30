defmodule Lux.Python do
  @moduledoc """
  Provides functions for executing Python code with variable bindings.

  The ~PY sigil is used to write Python code directly in Elixir files.
  The content inside ~PY sigils is preserved by the Elixir formatter
  to maintain proper Python indentation and formatting.

  ## Examples

      iex> require Lux.Python
      iex> Lux.Python.python variables: %{x: 40, y: 2} do
      ...>   ~PY'''
      ...>   x + y
      ...>   '''
      ...> end
      42
  """

  alias Venomous.SnakeArgs

  @type eval_option ::
          {:variables, map()}
          | {:timeout, pos_integer()}

  @type eval_options :: [eval_option()]

  @type package_info :: %{
          available: boolean(),
          version: String.t() | nil
        }

  @type import_result :: %{
          required(String.t()) => boolean() | String.t()
        }

  @module_path Application.app_dir(:lux, "priv/python")

  @doc """
  Evaluates Python code with optional variable bindings and other options.
  If `code_or_path` is a file path, it reads the file content and evaluates it.

  ## Options

    * `:variables` - A map of variables to bind in the Python context
    * `:timeout` - Timeout in milliseconds for Python execution

  ## Examples

      iex> Lux.Python.eval("x * 2", variables: %{x: 21})
      {:ok, 42}

      iex> Lux.Python.eval("os.getenv('TEST')", env: %{"TEST" => "value"})
      {:ok, "value"}
  """
  @spec eval(String.t(), eval_options()) :: {:ok, term()} | {:error, String.t()}
  def eval(code_or_path, opts \\ []) do
    code =
      if File.regular?(code_or_path), do: File.read!(code_or_path), else: code_or_path

    variables = Keyword.get(opts, :variables, %{})
    timeout = Keyword.get(opts, :timeout)
    func = Keyword.get(opts, :func, :execute)

    args = %SnakeArgs{
      module: :"lux.eval",
      func: func,
      args: [code, variables]
    }

    args = if timeout, do: Map.put(args, :timeout, timeout), else: args

    venomous_opts = [
      kill_on_exception: false
    ]

    venomous_opts =
      if timeout do
        [python_timeout: timeout] ++ venomous_opts
      else
        venomous_opts
      end

    args
    |> Venomous.python(venomous_opts)
    |> handle_python_result()
  end

  @doc """
  Same as `eval/2` but raises on error.

  ## Examples

      iex> Lux.Python.eval!("x + y", variables: %{x: 1, y: 2})
      3

      iex> Lux.Python.eval!("undefined_var")
      ** (RuntimeError) Python execution error: NameError: name 'undefined_var' is not defined
  """
  @spec eval!(String.t(), eval_options()) :: term() | no_return()
  def eval!(code, opts \\ []) do
    case eval(code, opts) do
      {:ok, result} ->
        result

      {:error, error} ->
        error_message =
          error
          |> String.split("\n")
          |> List.first()
          |> to_string()

        raise RuntimeError, "Python error: #{error_message}"
    end
  end

  @doc """
  Returns a main module path for the Python.
  """
  @spec module_path() :: String.t()
  def module_path, do: @module_path

  @doc """
  Returns dependant modules path for the Python.
  Returns nil if it is not ready.
  """
  @spec module_path(atom()) :: String.t() | nil
  def module_path(:deps),
    do:
      [@module_path]
      |> Enum.concat([".venv", "lib", "*", "site-packages"])
      |> Path.join()
      |> Path.wildcard()
      |> List.first()

  @doc """
  A macro that enables writing Python code directly in Elixir with variable bindings.
  Python code must be wrapped in ~PY sigil to bypass Elixir syntax checking.

  ## Options
    * `:variables` - A map of variables to bind in the Python context
    * `:timeout` - Timeout in milliseconds for Python execution

  ## Examples

      iex> require Lux.Python
      iex> Lux.Python.python variables: %{x: 40, y: 2} do
      ...>   ~PY'''
      ...>   x + y
      ...>   '''
      ...> end
      42

      iex> require Lux.Python
      iex> Lux.Python.python do
      ...>   ~PY'''
      ...>   def factorial(n):
      ...>       if n <= 1:
      ...>           return 1
      ...>       return n * factorial(n - 1)
      ...>   factorial(5)
      ...>   '''
      ...> end
      120
  """
  defmacro python(opts \\ [], do: {:sigil_PY, _, [{:<<>>, _, [code]}, []]}) do
    quote do
      variables = Keyword.get(unquote(opts), :variables, %{})
      timeout = Keyword.get(unquote(opts), :timeout)

      eval_opts =
        []
        |> Keyword.put(:variables, variables)
        |> Keyword.put_new_lazy(:timeout, fn -> timeout end)
        |> Enum.reject(fn {_, v} -> is_nil(v) end)

      Lux.Python.eval!(unquote(code), eval_opts)
    end
  end

  @doc false
  defmacro sigil_PY({:<<>>, _meta, [string]}, _modifiers) do
    quote do: unquote(string)
  end

  @doc """
  Lists all available Python packages and their versions.

  Returns a map where keys are package names and values are version strings.

  ## Examples

      iex> Lux.Python.list_packages()
      %{
        "pytest" => "7.4.0",
        "requests" => "2.31.0"
      }
  """
  @spec list_packages() :: {:ok, %{String.t() => String.t()}} | {:error, String.t()}
  def list_packages do
    args = %SnakeArgs{
      module: :"lux.eval",
      func: :get_available_packages,
      args: []
    }

    case Venomous.python(args) do
      %Venomous.SnakeError{error: error} -> {:error, to_string(error)}
      result when is_map(result) -> {:ok, result}
      {:error, error} -> {:error, to_string(error)}
    end
  end

  @doc """
  Checks if a Python package is available and returns its version information.

  ## Examples

      iex> Lux.Python.check_package("pytest")
      {:ok, %{available: true, version: "7.4.0"}}

      iex> Lux.Python.check_package("nonexistent_package")
      {:ok, %{available: false, version: nil}}
  """
  @spec check_package(String.t()) :: {:ok, package_info()} | {:error, String.t()}
  def check_package(package_name) when is_binary(package_name) do
    args = %SnakeArgs{
      module: :"lux.eval",
      func: :check_package,
      args: [package_name]
    }

    case Venomous.python(args) do
      %Venomous.SnakeError{error: error} -> {:error, to_string(error)}
      result when is_map(result) -> {:ok, result}
      {:error, error} -> {:error, to_string(error)}
    end
  end

  @doc """
  Attempts to import a Python package.

  Returns information about whether the import was successful.
  If the import fails, includes the error message.

  ## Examples

      iex> Lux.Python.import_package("json")
      {:ok, %{success: true, error: nil}}

      iex> Lux.Python.import_package("nonexistent_package")
      {:ok, %{success: false, error: "No module named 'nonexistent_package'"}}
  """
  @spec import_package(String.t()) :: {:ok, import_result()} | {:error, String.t()}
  def import_package(package_name) when is_binary(package_name) do
    args = %SnakeArgs{
      module: :"lux.eval",
      func: :import_package,
      args: [package_name]
    }

    args
    |> Venomous.python()
    |> handle_python_result()
  end

  defp handle_python_result(%Venomous.SnakeError{error: error}), do: {:error, to_string(error)}
  defp handle_python_result(%{error: error}) when is_binary(error), do: {:error, error}
  defp handle_python_result({:error, error}), do: {:error, to_string(error)}

  defp handle_python_result(result) when is_binary(result),
    do: {:ok, String.Chars.to_string(result)}

  defp handle_python_result(result), do: {:ok, result}
end
