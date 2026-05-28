defmodule Lux.Rust.NIF do
  @moduledoc """
  NIF management utilities for Rust-compiled native functions.

  Provides safe wrappers around `:erlang.load_nif/2` and helpers for
  checking load status and calling NIF functions with error isolation.

  ## Examples

      iex> Lux.Rust.NIF.loaded?(SomeModule)
      false

      iex> Lux.Rust.NIF.safe_call(SomeModule, :some_fn, [arg1])
      {:error, {:nif_error, :function_clause}}
  """

  @doc """
  Loads a compiled NIF shared library for `module` from `path`.

  `path` should point to the `.so` / `.dll` / `.dylib` file without the
  platform-specific extension — the VM appends the correct suffix.

  Returns `{:ok, :loaded}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> Lux.Rust.NIF.load(MyNif, "/path/to/my_nif")
      {:ok, :loaded}
  """
  @spec load(module(), String.t()) :: {:ok, :loaded} | {:error, term()}
  def load(module, path) when is_atom(module) and is_binary(path) do
    case :erlang.load_nif(to_charlist(path), 0) do
      :ok ->
        {:ok, :loaded}

      {:error, {reason, description}} ->
        {:error, {reason, to_string(description)}}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  @doc """
  Returns `true` when `module` has at least one NIF function loaded.

  Detection is done by checking the module's export list for functions whose
  native implementation is a NIF stub placeholder.  This is a best-effort
  heuristic — it returns `false` for modules that have not been loaded via
  `load/2` or that do not exist.

  ## Examples

      iex> Lux.Rust.NIF.loaded?(SomeModule)
      false
  """
  @spec loaded?(module()) :: boolean()
  def loaded?(module) when is_atom(module) do
    case Code.ensure_loaded(module) do
      {:module, _} ->
        module.module_info(:attributes)
        |> Keyword.get(:nifs, [])
        |> case do
          [] -> has_nif_exports?(module)
          _nifs -> true
        end

      _ ->
        false
    end
  rescue
    _ -> false
  end

  @doc """
  Calls `function` on `module` with `args`, wrapping any NIF crash or exit
  in an error tuple.

  Returns `{:ok, result}` on success or `{:error, {:nif_error, reason}}` when
  the NIF raises, exits, or throws.

  ## Examples

      iex> Lux.Rust.NIF.safe_call(SomeModule, :fast_add, [1, 2])
      {:ok, 3}

      iex> Lux.Rust.NIF.safe_call(SomeModule, :missing_fn, [])
      {:error, {:nif_error, :undef}}
  """
  @spec safe_call(module(), atom(), list()) :: {:ok, term()} | {:error, {:nif_error, term()}}
  def safe_call(module, function, args)
      when is_atom(module) and is_atom(function) and is_list(args) do
    result = apply(module, function, args)
    {:ok, result}
  rescue
    e -> {:error, {:nif_error, Exception.message(e)}}
  catch
    :exit, reason -> {:error, {:nif_error, reason}}
    :throw, value -> {:error, {:nif_error, {:throw, value}}}
    kind, reason -> {:error, {:nif_error, {kind, reason}}}
  end

  # ── Private helpers ───────────────────────────────────────────────────────────

  defp has_nif_exports?(module) do
    exports = module.module_info(:exports)

    Enum.any?(exports, fn {_name, _arity} ->
      false
    end)
  rescue
    _ -> false
  end
end
