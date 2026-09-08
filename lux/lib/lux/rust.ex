defmodule Lux.Rust do
  @moduledoc """
  Provides the Elixir API for Lux's Rust core.

  The Rust crate lives in `priv/rust` and is compiled as a memory-safe NIF
  via [Rustler](https://github.com/rusterlium/rustler). Primitive Elixir terms
  are converted to owned Rust values, operated on, and encoded back. Failures
  are returned as `{:error, reason}` and never panic across the FFI boundary.

  ## Components

  Rust Prisms and Beams implement native traits and are registered at NIF
  load. Elixir sees them as `%Lux.Prism{}` / `%Lux.Beam{}` structs whose
  `handler` is `{:rust, id}`. Lifecycle is explicit:

      uninitialized -> ready -> running -> ready | stopped

  See `Lux.Rust.Component` for view/run/init/shutdown.

  ## Examples

      iex> Lux.Rust.available?()
      true

      iex> Lux.Rust.add(40, 2)
      {:ok, 42}

      iex> Lux.Rust.echo(%{"n" => 1})
      {:ok, %{"n" => 1}}
  """

  alias Lux.Rust.Native

  @module_path Application.app_dir(:lux, "priv/rust")

  @typedoc "Reason returned when a NIF call fails."
  @type error_reason ::
          {:type, String.t(), String.t()}
          | {:conversion, String.t()}
          | {:runtime, String.t()}
          | :nif_not_loaded
          | term()

  @doc """
  Returns the path to the Rust crate (`priv/rust`).
  """
  @spec module_path() :: String.t()
  def module_path, do: @module_path

  @doc """
  Returns whether the Rust NIF is loaded and callable.
  """
  @spec available?() :: boolean()
  def available? do
    case Native.version() do
      version when is_binary(version) -> true
      {:ok, version} when is_binary(version) -> true
      _ -> false
    end
  rescue
    _ -> false
  catch
    :error, :nif_not_loaded -> false
    :error, {:nif_not_loaded, _} -> false
    _, _ -> false
  end

  @doc """
  Returns the compiled `lux_core` crate version.
  """
  @spec version() :: {:ok, String.t()} | {:error, error_reason()}
  def version, do: wrap(fn -> Native.version() end)

  @doc """
  Adds two 64-bit integers in Rust. Overflow is returned as an error.
  """
  @spec add(integer(), integer()) :: {:ok, integer()} | {:error, error_reason()}
  def add(a, b) when is_integer(a) and is_integer(b) do
    wrap(fn -> Native.add(a, b) end)
  end

  def add(_a, _b), do: {:error, {:type, "integer", "other"}}

  @doc """
  Divides two 64-bit integers in Rust. Division by zero is a runtime error.
  """
  @spec divide(integer(), integer()) :: {:ok, integer()} | {:error, error_reason()}
  def divide(a, b) when is_integer(a) and is_integer(b) do
    wrap(fn -> Native.divide(a, b) end)
  end

  def divide(_a, _b), do: {:error, {:type, "integer", "other"}}

  @doc """
  Round-trips an Elixir term through the Rust conversion layer.

  Supported primitives: `nil`, booleans, integers, floats, atoms, binaries,
  lists, maps, and tuples. PIDs and other BEAM-only terms cannot be re-encoded.
  """
  @spec echo(term()) :: {:ok, term()} | {:error, error_reason()}
  def echo(term), do: wrap(fn -> Native.echo(term) end)

  @doc """
  Describes an Elixir term after conversion to Rust.

  Returns a map with `"type"` and `"value"` keys.
  """
  @spec describe(term()) :: {:ok, map()} | {:error, error_reason()}
  def describe(term), do: wrap(fn -> Native.describe(term) end)

  @doc """
  Computes Fibonacci(n) on a dirty CPU scheduler.

  `n` must be `<= 92` so the result fits in `u64`.
  """
  @spec fib(non_neg_integer()) :: {:ok, non_neg_integer()} | {:error, error_reason()}
  def fib(n) when is_integer(n) and n >= 0 do
    wrap(fn -> Native.fib(n) end)
  end

  def fib(_n), do: {:error, {:type, "non_neg_integer", "other"}}

  @doc """
  Returns `{:ok, term}` encoded from Rust, used to verify ok-tuple construction.
  """
  @spec wrap_ok(term()) :: {:ok, term()} | {:error, error_reason()}
  def wrap_ok(term) do
    case Native.wrap_ok(term) do
      {:ok, value} -> {:ok, value}
      {:error, reason} -> {:error, reason}
      other -> {:ok, other}
    end
  rescue
    e in ArgumentError -> {:error, Exception.message(e)}
    e in ErlangError -> {:error, nif_reason(e)}
  catch
    :error, :nif_not_loaded -> {:error, :nif_not_loaded}
    :error, reason -> {:error, reason}
  end

  @doc """
  Returns a conversion type error from Rust. Intended for tests.
  """
  @spec type_error() :: {:error, error_reason()}
  def type_error do
    case wrap(fn -> Native.type_error() end) do
      {:ok, _} -> {:error, {:unexpected, "expected a type error"}}
      other -> other
    end
  end

  @doc """
  Returns whether the shared Tokio runtime used by async components is up.
  """
  @spec async_available?() :: boolean()
  def async_available? do
    Native.async_available() == true
  rescue
    _ -> false
  catch
    _, _ -> false
  end

  def wrap(fun) do
    case fun.() do
      {:error, reason} -> {:error, reason}
      {:ok, value} -> {:ok, value}
      value -> {:ok, value}
    end
  rescue
    e in ArgumentError -> {:error, Exception.message(e)}
    e in ErlangError -> {:error, nif_reason(e)}
  catch
    :error, :nif_not_loaded -> {:error, :nif_not_loaded}
    :error, reason -> {:error, reason}
  end

  defp nif_reason(%ErlangError{original: :nif_not_loaded}), do: :nif_not_loaded
  defp nif_reason(%ErlangError{original: original}), do: original
  defp nif_reason(other), do: other
end

defmodule Lux.Rust.Native do
  @moduledoc false
  # NIF stubs. Rustler replaces these at load time with the lux_core crate.
  use Rustler, otp_app: :lux, crate: "lux_core", path: "priv/rust"

  def version, do: :erlang.nif_error(:nif_not_loaded)
  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)
  def divide(_a, _b), do: :erlang.nif_error(:nif_not_loaded)
  def echo(_term), do: :erlang.nif_error(:nif_not_loaded)
  def describe(_term), do: :erlang.nif_error(:nif_not_loaded)
  def type_error, do: :erlang.nif_error(:nif_not_loaded)
  def fib(_n), do: :erlang.nif_error(:nif_not_loaded)
  def wrap_ok(_term), do: :erlang.nif_error(:nif_not_loaded)
  def component_list, do: :erlang.nif_error(:nif_not_loaded)
  def component_view(_id), do: :erlang.nif_error(:nif_not_loaded)
  def component_init(_id), do: :erlang.nif_error(:nif_not_loaded)
  def component_shutdown(_id), do: :erlang.nif_error(:nif_not_loaded)
  def component_status(_id), do: :erlang.nif_error(:nif_not_loaded)
  def component_run(_id, _input, _ctx), do: :erlang.nif_error(:nif_not_loaded)
  def component_run_async(_id, _input, _ctx), do: :erlang.nif_error(:nif_not_loaded)
  def async_available, do: :erlang.nif_error(:nif_not_loaded)
end
