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

  ## Examples

      iex> Lux.NodeJS.eval("export const main = ({x}) => x * 2", variables: %{x: 21})
      {:ok, 42}

      iex> Lux.NodeJS.eval("export const main = () => os.getenv('TEST')", env: %{"TEST" => "value"})
      {:ok, "value"}
  """
  @spec eval(String.t(), eval_options()) :: {:ok, term()} | {:error, String.t()}
  def eval(code, opts \\ []) do
    {variables, opts} = Keyword.pop(opts, :variables, %{})

    code
    |> do_eval(variables, opts, &NodeJS.call/3)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, "Call timed out."} -> {:error, :timeout}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Same as `eval/2`, but raises an error.
  """
  def eval!(code, opts \\ []) do
    {variables, opts} = Keyword.pop(opts, :variables, %{})
    do_eval(code, variables, opts, &NodeJS.call!/3)
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
    |> case do
      {:ok, %{"success" => true} = result} ->
        {:ok, result}

      {:ok, %{"error" => "ERR_MODULE_NOT_FOUND"}} ->
        {:error, "Cannot import package: #{package_name}"}

      {:ok, %{"error" => error}} ->
        {:error, error}

      {:error, error} ->
        {:error, error}
    end
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

  defp do_eval(code, variables, opts, fun) do
    filename = create_file_name(code)

    with {:ok, node_modules_path} <- maybe_create_node_modules(),
         file_path = Path.join(node_modules_path, filename),
         :ok <- File.write(file_path, code) do
      fun.({file_path, "main"}, [variables], opts)
    end
  end

  defp maybe_create_node_modules do
    node_modules = Path.join(@module_path, "node_modules/lux")

    if !File.exists?(node_modules) do
      File.mkdir_p(node_modules)
    end

    {:ok, node_modules}
  end

  defp create_file_name(code) do
    hash = :sha |> :crypto.hash(code) |> Base.encode16(case: :lower)
    "#{hash}.mjs"
  end
end
