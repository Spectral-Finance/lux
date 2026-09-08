defmodule Lux.Rust.Component do
  @moduledoc """
  Elixir API for Rust-defined Prisms and Beams.

  Components are registered in the `lux_core` NIF at load time. Each one
  implements a Rust handler, is converted into a `%Lux.Prism{}` /
  `%Lux.Beam{}` view, and is executed through an explicit lifecycle:

      uninitialized -> ready -> running -> ready | stopped

  Handler functions never retain BEAM pointers: input is copied into owned
  Rust values before work starts, so dirty-CPU and async runtimes can run
  without pinning term memory.

  ## Built-in components

  | id         | kind  | notes                                |
  | ---------- | ----- | ------------------------------------ |
  | `echo`     | prism | identity; conversion smoke test      |
  | `hash`     | prism | default hasher over a converted term |
  | `fib`      | prism | Fibonacci(n) for n <= 92             |
  | `map_get`  | prism | `map[key]` lookup                    |
  | `sleep`    | prism | Tokio timer then `%{"ok" => true}`   |
  | `sequence` | beam  | `hash` then `echo`                   |

  File-style ids (`"echo.rs"`) resolve to the same component.

  ## Examples

      iex> {:ok, view} = Lux.Rust.Component.view("echo")
      iex> view.handler
      {:rust, "echo"}

      iex> Lux.Rust.Component.run("echo", %{"n" => 1})
      {:ok, %{"n" => 1}}
  """

  alias Lux.Rust
  alias Lux.Rust.Native

  @type id :: String.t() | atom()
  @type error_reason :: Lux.Rust.error_reason()

  @doc """
  Lists registered Rust components as `%{id, kind, lifecycle}` maps.
  """
  @spec list() :: {:ok, [map()]} | {:error, error_reason()}
  def list, do: Rust.wrap(fn -> Native.component_list() end)

  @doc """
  Returns a `%Lux.Prism{}` or `%Lux.Beam{}` view for `id`.

  The prism `handler` field is `{:rust, id}` so `Lux.Prism.run/2` can dispatch
  without a Python/Node interpreter.
  """
  @spec view(id()) :: {:ok, Lux.Prism.t() | Lux.Beam.t()} | {:error, error_reason()}
  def view(id) when is_binary(id) or is_atom(id) do
    case Rust.wrap(fn -> Native.component_view(to_string(id)) end) do
      {:ok, raw} -> {:ok, to_struct(raw)}
      other -> other
    end
  end

  @doc """
  Transitions `id` from `uninitialized` (or `ready`) to `ready`.

  Stopped components cannot be re-initialized.
  """
  @spec init(id()) :: {:ok, atom() | String.t() | map()} | {:error, error_reason()}
  def init(id) when is_binary(id) or is_atom(id) do
    Rust.wrap(fn -> Native.component_init(to_string(id)) end)
  end

  @doc """
  Transitions `id` to `stopped`. Running work is not cancelled; further
  `run/3` calls fail until a new process loads the NIF.
  """
  @spec shutdown(id()) :: {:ok, atom() | String.t() | map()} | {:error, error_reason()}
  def shutdown(id) when is_binary(id) or is_atom(id) do
    Rust.wrap(fn -> Native.component_shutdown(to_string(id)) end)
  end

  @doc """
  Returns the current lifecycle atom or status map for `id`.
  """
  @spec status(id()) :: {:ok, atom() | String.t() | map()} | {:error, error_reason()}
  def status(id) when is_binary(id) or is_atom(id) do
    Rust.wrap(fn -> Native.component_status(to_string(id)) end)
  end

  @doc """
  Runs a registered Prism or Beam synchronously on a dirty CPU scheduler.

  `context` defaults to `%{}`. Ids may be `"echo"` or `"echo.rs"`.
  The component is auto-initialized on first run.
  """
  @spec run(id(), term()) :: {:ok, term()} | {:error, error_reason()}
  @spec run(id(), term(), term()) :: {:ok, term()} | {:error, error_reason()}
  def run(id, input, context \\ %{}) when is_binary(id) or is_atom(id) do
    Rust.wrap(fn -> Native.component_run(to_string(id), input, context) end)
  end

  @doc """
  Runs the async handler for `id` (Tokio). Errors if the component has no
  async handler. Uses a dirty CPU NIF so the runtime wait cannot stall a
  normal BEAM scheduler.
  """
  @spec run_async(id(), term()) :: {:ok, term()} | {:error, error_reason()}
  @spec run_async(id(), term(), term()) :: {:ok, term()} | {:error, error_reason()}
  def run_async(id, input, context \\ %{}) when is_binary(id) or is_atom(id) do
    Rust.wrap(fn -> Native.component_run_async(to_string(id), input, context) end)
  end

  @doc """
  Returns whether the shared Tokio runtime started successfully.
  """
  @spec async_available?() :: boolean()
  def async_available?, do: Rust.async_available?()

  defp to_struct(raw) when is_map(raw) do
    id = get(raw, :id)
    kind = get(raw, :kind)
    name = get(raw, :name) || ""
    description = get(raw, :description) || ""
    input_schema = get(raw, :input_schema)
    output_schema = get(raw, :output_schema)
    handler = rust_handler(get(raw, :handler) || id)
    module_name = get(raw, :module_name) || rust_module_name(id)

    case kind do
      k when k in [:beam, "beam"] ->
        Lux.Beam.new(
          id: id,
          name: name,
          module_name: module_name,
          description: description,
          input_schema: input_schema,
          output_schema: output_schema,
          definition: []
        )

      _ ->
        Lux.Prism.new(
          id: id,
          name: name,
          module_name: module_name,
          description: description,
          input_schema: input_schema,
          output_schema: output_schema,
          handler: handler
        )
    end
  end

  defp to_struct(%Lux.Prism{} = prism), do: prism
  defp to_struct(%Lux.Beam{} = beam), do: beam
  defp to_struct(other), do: other

  defp get(map, key) when is_atom(key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp rust_handler({:rust, id}), do: {:rust, to_string(id)}
  defp rust_handler(id) when is_binary(id), do: {:rust, id}
  defp rust_handler(id) when is_atom(id), do: {:rust, Atom.to_string(id)}
  defp rust_handler(_), do: nil

  defp rust_module_name(id) when is_binary(id) do
    "Lux.Rust.Components." <> Macro.camelize(id)
  end

  defp rust_module_name(id) when is_atom(id), do: rust_module_name(Atom.to_string(id))
  defp rust_module_name(_), do: "Lux.Rust.Components.Unknown"
end
