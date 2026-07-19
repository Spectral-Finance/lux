defmodule Lux.NodeJS do
  @moduledoc """
  Provides functions for executing Node.js code with variable bindings.

  The ~JS sigil is used to write Node.js code directly in Elixir files.
  In the Node.js code, you have to export a function named `main` that takes
  an object as an argument and returns a value.

      export const main = ({x, y}) => x + y

  ## Examples

      iex> require Lux.NodeJS
      iex> Lux.NodeJS.nodejs variables: %{x: 40, y: 2} do
      ...>   ~JS'''
      ...>   export const main = ({x, y}) => x + y
      ...>   '''
      ...> end
      42

  ## Error Handling

  All public functions return `{:ok, result}` on success or `{:error, reason}`
  on failure. Possible error reasons include:

    * `:timeout` - Node.js execution exceeded the specified timeout.
      When a timeout occurs, the Node.js supervisor is restarted to
      prevent resource leaks from the un-canceled Node.js process.
    * `:invalid_code` - The provided code is empty or invalid.
    * `string()` - Other error messages from the Node.js runtime.
  """

  @type eval_option ::
          {:variables, map()}
          | {:timeout, pos_integer()}

  @type eval_options :: [eval_option()]

  @type import_result :: %{
          required(String.t()) => boolean() | String.t()
        }

  @module_path Application.app_dir(:lux, "priv/node")

  @doc """
  Evaluates Node.js code with optional variable bindings and other options.

  ## Options

    * `:variables` - A map of variables to bind in the Node.js context
    * `:timeout` - Timeout in milliseconds for Node.js execution

  ## Returns

    * `{:ok, result}` - Successfully evaluated, returns the result
    * `{:error, :timeout}` - Execution exceeded the timeout
    * `{:error, :invalid_code}` - Code is empty or invalid
    * `{:error, reason}` - Other error from the Node.js runtime

  ## Examples

      iex> Lux.NodeJS.eval("export const main = ({x}) => x * 2", variables: %{x: 21})
      {:ok, 42}

      iex> Lux.NodeJS.eval("export const main = () => 42", timeout: 5000)
      {:ok, 42}
  """
  @spec eval(String.t(), eval_options()) :: {:ok, term()} | {:error, term()}
  def eval(code, opts \\ []) do
    with {:ok, code} <- validate_code(code) do
      {variables, opts} = Keyword.pop(opts, :variables, %{})

      code
      |> do_eval(variables, opts, &NodeJS.call/3)
      |> handle_eval_result()
    end
  end

  @doc """
  Same as `eval/2`, but raises an error.
  """
  def eval!(code, opts \\ []) do
    with {:ok, code} <- validate_code(code) do
      {variables, opts} = Keyword.pop(opts, :variables, %{})
      do_eval(code, variables, opts, &NodeJS.call!/3)
    end
  end

  @doc """
  Returns a main module path for the Node.js.
  """
  @spec module_path() :: String.t()
  def module_path, do: @module_path

  @spec child_spec(keyword()) :: :supervisor.child_spec()
  def child_spec(opts \\ []) do
    NodeJS.Supervisor.child_spec([path: module_path()] ++ opts)
  end

  @doc """
  Attempts to import a Node.js package.
  Currently, it will modify `priv/node/package.json` and `priv/node/package_lock.json` files.

  ## Options

    * `:update_lock_file` - Whether to update the lock file after importing the package (default: true)
    * `:timeout` - Timeout in milliseconds for Node.js execution

  """
  @spec import_package(String.t(), keyword()) :: {:ok, import_result()} | {:error, String.t()}
  def import_package(package_name, opts \\ []) when is_binary(package_name) do
    {update_lock_file, opts} = Keyword.pop(opts, :update_lock_file, true)

    {"lux.mjs", "importPackage"}
    |> NodeJS.call([package_name, %{update_lock_file: update_lock_file}], opts)
    |> handle_import_result()
  end

  @doc """
  A macro for executing Node.js code with variable bindings.
  Node.js code should be wrapped in a sigil ~JS to bypass Elixir syntax checking.
  """
  defmacro nodejs(opts \\ [], do: {:sigil_JS, _, [{:<<>>, _, [code]}, []]}) do
    quote do
      Lux.NodeJS.eval(unquote(code), unquote(opts))
    end
  end

  @doc false
  defmacro sigil_JS({:<<>>, _meta, [string]}, _modifiers) do
    quote do: unquote(string)
  end

  defp validate_code(""), do: {:error, :invalid_code}
  defp validate_code(code) when is_binary(code) do
    if String.trim(code) == "" do
      {:error, :invalid_code}
    else
      {:ok, code}
    end
  end
  defp validate_code(_), do: {:error, :invalid_code}

  defp do_eval(code, variables, opts, fun) do
    filename = create_file_name(code)

    with {:ok, filepath} <- ensure_module_path(filename),
         :ok <- File.write(filepath, code) do
      fun.({filename, "main"}, [variables], opts)
    end
  end

  defp handle_eval_result({:ok, result}), do: {:ok, result}
  defp handle_eval_result({:error, "Call timed out."}) do
    restart_nodejs_supervisor()
    {:error, :timeout}
  end
  defp handle_eval_result({:error, error}), do: {:error, error}

  defp handle_import_result({:ok, %{"success" => true} = result}) do
    {:ok, result}
  end
  defp handle_import_result({:ok, %{"error" => "ERR_MODULE_NOT_FOUND"}}) do
    {:error, "Cannot import package: #{package_name}"}
  end
  defp handle_import_result({:ok, %{"error" => error}}) do
    {:error, error}
  end
  defp handle_import_result({:error, "Call timed out."}) do
    restart_nodejs_supervisor()
    {:error, :timeout}
  end
  defp handle_import_result({:error, error}) do
    {:error, error}
  end

  defp ensure_module_path(filename) do
    filepath = Path.join(@module_path, filename)
    module_path = Path.dirname(filepath)

    if !File.exists?(module_path) do
      File.mkdir_p(module_path)
    end

    {:ok, filepath}
  end

  defp create_file_name(code) do
    hash = :sha |> :crypto.hash(code) |> Base.encode16(case: :lower)
    Path.join(["node_modules", "lux", "#{hash}.mjs"])
  end

  defp restart_nodejs_supervisor do
    Lux.Supervisor
    |> Supervisor.which_children()
    |> Enum.find_value(fn {_id, pid, _type, modules} ->
      if pid != :undefined and modules == [NodeJS.Supervisor], do: pid, else: nil
    end)
    |> case do
      nil -> :ok
      pid -> Process.exit(pid, :kill)
    end
  end
end
