defmodule Lux.Rust.Component do
  @moduledoc """
  Bridge layer for defining Lux Prisms and Beams in Rust via Rustler NIFs.

  `Lux.Rust.Component` provides compile-time macros (`rust_prism/2`,
  `rust_beam/2`) that generate a fully-conformant `Lux.Prism` or
  `Lux.Beam` module backed by a compiled Rustler NIF, plus a set of
  runtime functions for NIF lifecycle management, async dispatch, and
  an ETS-backed component registry.

  ## Architecture overview

  ```
  Elixir caller
       │
       ▼
  Lux.Rust.Component   ← macro-generated Prism / Beam module
       │
       ▼  load_nif / call_nif
  Rustler NIF (.so / .dll)
       │
       ▼
  Rust handler function
  ```

  ## Quick start — Rust-backed Prism

  ### 1. Write the Rust NIF

  In `native/my_prism/src/lib.rs`:

  ```rust
  use rustler::{Encoder, Env, NifResult, Term};

  #[rustler::nif]
  fn handler(input: String) -> NifResult<String> {
      // heavy processing happens here, safely off the BEAM scheduler
      Ok(format!("processed: {}", input))
  }

  rustler::init!("Elixir.MyApp.Prisms.MyRustPrism", [handler]);
  ```

  And the matching `native/my_prism/Cargo.toml`:

  ```toml
  [package]
  name    = "my_prism"
  version = "0.1.0"
  edition = "2021"

  [lib]
  name       = "my_prism"
  crate-type = ["cdylib"]

  [dependencies]
  rustler = "0.34"
  ```

  ### 2. Declare the Elixir wrapper

  ```elixir
  defmodule MyApp.Prisms.MyRustPrism do
    use Lux.Rust.Component

    rust_prism MyApp.Prisms.MyRustPrism,
      name: "My Rust Prism",
      description: "CPU-intensive processing offloaded to Rust",
      nif_path: Application.app_dir(:my_app, "priv/native/my_prism"),
      input_schema: %{
        type: :object,
        properties: %{
          text: %{type: :string, description: "Text to process"}
        },
        required: ["text"]
      }
  end
  ```

  Then call it like any other Prism:

  ```elixir
  {:ok, result} = MyApp.Prisms.MyRustPrism.run(%{"text" => "hello"})
  ```

  ## Quick start — Rust-backed Beam

  ```elixir
  defmodule MyApp.Beams.PipelineBeam do
    use Lux.Rust.Component

    rust_beam MyApp.Beams.PipelineBeam,
      name: "Rust Pipeline Beam",
      description: "Multi-step pipeline implemented in Rust",
      nif_path: Application.app_dir(:my_app, "priv/native/pipeline"),
      input_schema: %{
        type: :object,
        properties: %{
          data: %{type: :array}
        }
      }
  end
  ```

  ## Async dispatch

  Long-running NIFs can be called asynchronously to avoid blocking the
  calling process:

  ```elixir
  {:ok, task} = Lux.Rust.Component.async_call(MyNif, :heavy_fn, [large_input])
  {:ok, result} = Lux.Rust.Component.await_result(task, 30_000)
  ```

  ## Component registry

  All components registered via `register_component/2` are stored in an
  ETS table (`#{inspect(@table)}`) and can be introspected at runtime:

  ```elixir
  :ok = Lux.Rust.Component.register_component(MyNif, %{version: "1.0"})
  {:ok, info} = Lux.Rust.Component.component_info(MyNif)
  components  = Lux.Rust.Component.list_components()
  ```
  """

  require Logger

  @table :lux_rust_components

  # ── use Lux.Rust.Component ───────────────────────────────────────────────────

  defmacro __using__(_opts) do
    quote do
      import Lux.Rust.Component, only: [rust_prism: 2, rust_beam: 2]
    end
  end

  # ── DSL macros ───────────────────────────────────────────────────────────────

  @doc """
  Declares the current module as a Rust-backed `Lux.Prism`.

  Generates:
  - `view/0` — returns the `%Lux.Prism{}` struct
  - `run/2` — delegates to the Rust NIF via `Lux.Rust.Component.call_nif/3`
  - `handler/2` — satisfies the `Lux.Prism` behaviour callback

  ## Options

  - `:name` — human-readable name (defaults to the stringified module name)
  - `:description` — short description string (default: `""`)
  - `:nif_path` — path to the compiled `.so`/`.dll` (without extension)
  - `:input_schema` — JSON-schema map for input validation
  - `:output_schema` — JSON-schema map for output validation

  ## Example

      rust_prism MyApp.Prisms.Tokeniser,
        name: "Tokeniser",
        description: "Fast BPE tokenisation in Rust",
        nif_path: Application.app_dir(:my_app, "priv/native/tokeniser"),
        input_schema: %{type: :object, properties: %{text: %{type: :string}}}
  """
  defmacro rust_prism(module, opts) do
    quote do
      @behaviour Lux.Prism

      alias Lux.Prism

      @rust_prism_module unquote(module)
      @rust_prism_opts unquote(opts)
      @rust_prism_module_name __MODULE__ |> Module.split() |> Enum.join(".")
      @rust_prism_nif_path Keyword.get(unquote(opts), :nif_path, "")

      @rust_prism_struct Lux.Prism.new(
                           id: Keyword.get(unquote(opts), :id, Lux.UUID.generate()),
                           name: Keyword.get(unquote(opts), :name, @rust_prism_module_name),
                           module_name: @rust_prism_module_name,
                           description: Keyword.get(unquote(opts), :description, ""),
                           input_schema: Keyword.get(unquote(opts), :input_schema),
                           output_schema: Keyword.get(unquote(opts), :output_schema),
                           examples: Keyword.get(unquote(opts), :examples, [])
                         )

      @doc "Returns the `%Lux.Prism{}` struct for this Rust-backed prism."
      def view do
        %{@rust_prism_struct | handler: &__MODULE__.handler/2}
      end

      @doc "Executes the Rust NIF handler with the given input and context."
      def run(input, context \\ nil) do
        handler(input, context)
      end

      @impl Lux.Prism
      def handler(input, _context) do
        Lux.Rust.Component.call_nif(__MODULE__, :handler, [input])
      end

      defoverridable run: 2, handler: 2
    end
  end

  @doc """
  Declares the current module as a Rust-backed `Lux.Beam`.

  Generates `view/0` and `run/2`, delegating execution to the Rust NIF.

  ## Options

  - `:name` — human-readable name
  - `:description` — short description
  - `:nif_path` — path to the compiled NIF library
  - `:input_schema` / `:output_schema` — JSON-schema maps
  - `:timeout` — maximum run duration in ms (default: 5 minutes)

  ## Example

      rust_beam MyApp.Beams.DataPipeline,
        name: "Data Pipeline",
        description: "High-throughput Rust pipeline",
        nif_path: Application.app_dir(:my_app, "priv/native/pipeline"),
        timeout: :timer.seconds(60)
  """
  defmacro rust_beam(module, opts) do
    quote do
      @rust_beam_module unquote(module)
      @rust_beam_opts unquote(opts)
      @rust_beam_module_name __MODULE__ |> Module.split() |> Enum.join(".")
      @rust_beam_nif_path Keyword.get(unquote(opts), :nif_path, "")

      @rust_beam_struct %Lux.Beam{
        id: Keyword.get(unquote(opts), :id, Lux.UUID.generate()),
        name: Keyword.get(unquote(opts), :name, @rust_beam_module_name),
        module_name: @rust_beam_module_name,
        description: Keyword.get(unquote(opts), :description, ""),
        input_schema: Keyword.get(unquote(opts), :input_schema),
        output_schema: Keyword.get(unquote(opts), :output_schema),
        timeout: Keyword.get(unquote(opts), :timeout, :timer.minutes(5)),
        generate_execution_log: Keyword.get(unquote(opts), :generate_execution_log, false)
      }

      @doc "Returns the `%Lux.Beam{}` struct for this Rust-backed beam."
      def view, do: @rust_beam_struct

      @doc "Executes the Rust NIF beam handler with the given input."
      def run(input, _opts \\ []) do
        Lux.Rust.Component.call_nif(__MODULE__, :run, [input])
      end

      defoverridable run: 2
    end
  end

  # ── NIF lifecycle ─────────────────────────────────────────────────────────────

  @doc """
  Loads a compiled Rustler NIF from the given filesystem path.

  The path must point to the shared library **without** its platform
  extension (`.so`, `.dylib`, or `.dll`); the Erlang loader appends the
  correct suffix automatically.

  Returns `{:ok, :loaded}` on success or `{:error, reason}` if the
  library cannot be found or loaded.

  ## Example

      iex> Lux.Rust.Component.load_nif(MyNif, "/app/priv/native/my_nif")
      {:ok, :loaded}
  """
  @spec load_nif(module(), String.t()) :: {:ok, :loaded} | {:error, term()}
  def load_nif(module, path) when is_atom(module) and is_binary(path) do
    charlist_path = String.to_charlist(path)

    case :erlang.load_nif(charlist_path, 0) do
      :ok ->
        Logger.info("[Lux.Rust.Component] Loaded NIF for #{module} from #{path}")
        {:ok, :loaded}

      {:error, {:reload, _}} ->
        Logger.debug("[Lux.Rust.Component] NIF for #{module} already loaded")
        {:ok, :loaded}

      {:error, {reason, text}} ->
        msg = "#{inspect(reason)}: #{text}"
        Logger.warning("[Lux.Rust.Component] Failed to load NIF for #{module}: #{msg}")
        {:error, msg}

      {:error, reason} ->
        Logger.warning("[Lux.Rust.Component] Failed to load NIF for #{module}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Calls a function exported from a loaded Rustler NIF module.

  Looks up `:handler` on the given module or, for modules that implement
  `Lux.Rust.Component.Behaviour`, delegates to `handle_call/2`.  For
  plain NIF modules it performs a direct `apply/3`.

  Returns `{:ok, result}` or `{:error, reason}`.

  ## Example

      iex> Lux.Rust.Component.call_nif(MyNif, :tokenise, ["hello world"])
      {:ok, ["hello", "world"]}
  """
  @spec call_nif(module(), atom(), list()) :: {:ok, term()} | {:error, term()}
  def call_nif(module, function_name, args) when is_atom(module) and is_atom(function_name) do
    cond do
      behaviour_impl?(module) ->
        module.handle_call(function_name, args)

      function_exported?(module, function_name, length(args)) ->
        apply(module, function_name, args)

      true ->
        {:error, "#{module}.#{function_name}/#{length(args)} is not exported"}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  @doc """
  Returns `true` when a NIF has been loaded for the given module.

  Uses `:erlang.module_info/1` to check whether any native functions are
  present.  Returns `false` for unloaded or non-existent modules.

  ## Example

      iex> Lux.Rust.Component.nif_loaded?(MyNif)
      false
  """
  @spec nif_loaded?(module()) :: boolean()
  def nif_loaded?(module) when is_atom(module) do
    case Code.ensure_loaded(module) do
      {:module, _} ->
        module.module_info(:native)

      _ ->
        false
    end
  rescue
    _ -> false
  end

  @doc """
  Wraps a NIF call with a timeout.

  Executes `fun` in a supervised `Task` and awaits the result for up to
  `timeout_ms` milliseconds.  Returns `{:ok, result}` on success or
  `{:error, :timeout}` / `{:error, reason}` on failure.

  ## Example

      iex> Lux.Rust.Component.with_timeout(5_000, fn ->
      ...>   Lux.Rust.Component.call_nif(MyNif, :slow_fn, [])
      ...> end)
      {:ok, "done"}
  """
  @spec with_timeout(pos_integer(), (-> {:ok, term()} | {:error, term()})) ::
          {:ok, term()} | {:error, term()}
  def with_timeout(timeout_ms, fun) when is_integer(timeout_ms) and is_function(fun, 0) do
    task = Task.async(fun)

    case Task.yield(task, timeout_ms) || Task.shutdown(task) do
      {:ok, {:ok, result}} -> {:ok, result}
      {:ok, {:error, reason}} -> {:error, reason}
      {:ok, result} -> {:ok, result}
      {:exit, reason} -> {:error, "NIF task exited: #{inspect(reason)}"}
      nil -> {:error, :timeout}
    end
  end

  @doc """
  Initialises resources for a Rust component.

  Calls `lifecycle_init/0` on the module if it is exported, then
  registers the component in the ETS registry.  Falls back gracefully
  when the callback is absent.

  Returns `{:ok, :started}` on success or `{:error, reason}`.

  ## Example

      iex> Lux.Rust.Component.lifecycle_start(MyNif)
      {:ok, :started}
  """
  @spec lifecycle_start(module()) :: {:ok, :started} | {:error, term()}
  def lifecycle_start(module) when is_atom(module) do
    result =
      if function_exported?(module, :lifecycle_init, 0) do
        module.lifecycle_init()
      else
        :ok
      end

    case result do
      :ok ->
        register_component(module, %{status: :started, started_at: DateTime.utc_now()})
        {:ok, :started}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  @doc """
  Cleans up resources for a Rust component.

  Calls `lifecycle_cleanup/0` on the module if exported, then removes
  the component from the ETS registry.

  Returns `{:ok, :stopped}` on success or `{:error, reason}`.

  ## Example

      iex> Lux.Rust.Component.lifecycle_stop(MyNif)
      {:ok, :stopped}
  """
  @spec lifecycle_stop(module()) :: {:ok, :stopped} | {:error, term()}
  def lifecycle_stop(module) when is_atom(module) do
    result =
      if function_exported?(module, :lifecycle_cleanup, 0) do
        module.lifecycle_cleanup()
      else
        :ok
      end

    case result do
      :ok ->
        ensure_table()
        :ets.delete(@table, module)
        {:ok, :stopped}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  # ── Async support ─────────────────────────────────────────────────────────────

  @doc """
  Calls a NIF function asynchronously via `Task.async/1`.

  Returns `{:ok, task}` immediately; use `await_result/2` to collect the
  result later.  This prevents long-running NIFs from blocking the
  calling process.

  ## Example

      iex> {:ok, task} = Lux.Rust.Component.async_call(MyNif, :slow_fn, [data])
      iex> {:ok, result} = Lux.Rust.Component.await_result(task, 30_000)
  """
  @spec async_call(module(), atom(), list()) :: {:ok, Task.t()}
  def async_call(module, function_name, args)
      when is_atom(module) and is_atom(function_name) and is_list(args) do
    task = Task.async(fn -> call_nif(module, function_name, args) end)
    {:ok, task}
  end

  @doc """
  Awaits the result of an async NIF call started with `async_call/3`.

  Blocks for up to `timeout_ms` milliseconds (default: `5_000`).
  Returns `{:ok, result}`, `{:error, reason}`, or `{:error, :timeout}`.

  ## Example

      iex> {:ok, task} = Lux.Rust.Component.async_call(MyNif, :compute, [42])
      iex> {:ok, _result} = Lux.Rust.Component.await_result(task, 10_000)
  """
  @spec await_result(Task.t(), pos_integer()) :: {:ok, term()} | {:error, term()}
  def await_result(%Task{} = task, timeout_ms \\ 5_000) do
    case Task.yield(task, timeout_ms) || Task.shutdown(task) do
      {:ok, {:ok, result}} -> {:ok, result}
      {:ok, {:error, reason}} -> {:error, reason}
      {:ok, result} -> {:ok, result}
      {:exit, reason} -> {:error, "async NIF task exited: #{inspect(reason)}"}
      nil -> {:error, :timeout}
    end
  end

  # ── Component registry ────────────────────────────────────────────────────────

  @doc """
  Registers a Rust component in the ETS registry with the given metadata.

  `metadata` is an arbitrary map that is stored alongside the component
  module reference.  Any existing entry for `module` is overwritten.

  Returns `:ok`.

  ## Example

      iex> Lux.Rust.Component.register_component(MyNif, %{version: "1.2.0"})
      :ok
  """
  @spec register_component(module(), map()) :: :ok
  def register_component(module, metadata \\ %{}) when is_atom(module) and is_map(metadata) do
    ensure_table()

    entry = Map.merge(%{module: module, registered_at: DateTime.utc_now()}, metadata)
    :ets.insert(@table, {module, entry})
    :ok
  end

  @doc """
  Returns a list of all registered Rust components.

  Each element is the metadata map that was supplied to
  `register_component/2` plus a `:module` key.

  ## Example

      iex> Lux.Rust.Component.list_components()
      [%{module: MyNif, version: "1.2.0", registered_at: ~U[...]}]
  """
  @spec list_components() :: [map()]
  def list_components do
    ensure_table()

    @table
    |> :ets.tab2list()
    |> Enum.map(fn {_key, info} -> info end)
  end

  @doc """
  Returns the registry entry for a specific component module.

  Returns `{:ok, info}` when the module is registered or
  `{:error, :not_found}` otherwise.

  ## Example

      iex> Lux.Rust.Component.component_info(MyNif)
      {:ok, %{module: MyNif, version: "1.2.0", registered_at: ~U[...]}}
  """
  @spec component_info(module()) :: {:ok, map()} | {:error, :not_found}
  def component_info(module) when is_atom(module) do
    ensure_table()

    case :ets.lookup(@table, module) do
      [{^module, info}] -> {:ok, info}
      [] -> {:error, :not_found}
    end
  end

  # ── Private helpers ───────────────────────────────────────────────────────────

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined -> :ets.new(@table, [:named_table, :public, :set])
      _ -> @table
    end
  end

  defp behaviour_impl?(module) do
    function_exported?(module, :nif_path, 0) and
      function_exported?(module, :nif_functions, 0) and
      function_exported?(module, :handle_call, 2)
  end
end
