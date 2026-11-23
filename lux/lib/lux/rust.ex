defmodule Lux.Rust do
  @moduledoc """
  Native Rust core for Lux, bridged into the BEAM via
  [Rustler](https://hexdocs.pm/rustler).

  This module is the Elixir-facing API for the high-performance Rust code that
  lives in `priv/rust`. It exposes a small, safe surface of NIF-backed functions
  for compute-intensive work (checksums, parsing, math) and demonstrates the
  end-to-end type-conversion and error-propagation framework that the rest of
  Lux can build on.

  ## Architecture

  The Rust crate (`priv/rust`) is a `cdylib` that uses `rustler::init!` to
  register its NIFs into this module (`Elixir.Lux.Rust`). When the library is
  loaded, Rustler replaces the `:nif_not_loaded_yet` stubs below with the
  compiled implementations. If the library has not been built, the stubs keep
  their fallback behaviour so the rest of Lux still works:

  * Pure functions raise `:erlang.nif_error(:nif_not_loaded)` when called
    without the native library.
  * Fallible functions return `{:error, :nif_not_loaded}`.

  ## Building

  The native library is built with:

      mix rust.build

  or directly with Cargo:

      cd priv/rust && cargo build --release

  ## Examples

      iex> Lux.Rust.add(2, 3)
      5

      iex> Lux.Rust.factorial(5)
      {:ok, 120}

      iex> Lux.Rust.factorial(-1)
      {:error, %{kind: :invalid_argument, message: "factorial is undefined for negative numbers", ...}}

      iex> Lux.Rust.core_version()
      {:ok, "0.1.0"}
  """

  @on_load :load_nif

  @typedoc """
  A structured error returned by the Rust core.

  * `:kind` - one of `:invalid_argument`, `:decode`, `:encode`, `:panic`,
    `:internal`, or `:badarg`.
  * `:message` - a human-readable description.
  * `:detail` - optional extra context (may be `nil`).
  """
  @type rust_error :: %{
          required(:kind) => atom(),
          required(:message) => String.t(),
          optional(:detail) => String.t() | nil
        }

  # -------------------------------------------------------------------------
  # NIF loader. Invoked automatically when this module is first loaded.
  # -------------------------------------------------------------------------

  @doc false
  def load_nif do
    path = :filename.join(:code.priv_dir(:lux), ~c"rust/target/release/liblux_rust")

    case :erlang.load_nif(path, 0) do
      :ok ->
        :ok

      {:error, reason} ->
        IO.warn("""
        Could not load the Lux Rust NIF library at #{path}: #{inspect(reason)}.

        The native core is optional; Lux falls back to the pure-Elixir stubs in
        `Lux.Rust`. To enable the native core, run:

            mix rust.build
        """)

        :ok
    end
  end

  # -------------------------------------------------------------------------
  # Fallback stubs. Replaced by the compiled NIFs once the library loads.
  # -------------------------------------------------------------------------

  @doc "Returns the version of the compiled Rust core."
  @spec core_version() :: {:ok, String.t()} | {:error, :nif_not_loaded}
  def core_version, do: {:error, :nif_not_loaded}

  @doc "Adds two integers."
  @spec add(integer(), integer()) :: integer()
  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Multiplies two integers."
  @spec multiply(integer(), integer()) :: integer()
  def multiply(_a, _b), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Sums a list of integers."
  @spec sum_list([integer()]) :: integer()
  def sum_list(_values), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Reverses a list of integers."
  @spec reverse_list([integer()]) :: [integer()]
  def reverse_list(_values), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Sums the bytes of a binary."
  @spec binary_checksum(binary()) :: integer()
  def binary_checksum(_data), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Converts a string to uppercase."
  @spec to_uppercase(String.t()) :: String.t()
  def to_uppercase(_input), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Joins a list of strings with a separator."
  @spec join_strings([String.t()], String.t()) :: String.t()
  def join_strings(_parts, _separator), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Computes the factorial of `n`."
  @spec factorial(integer()) :: {:ok, integer()} | {:error, rust_error()}
  def factorial(_n), do: {:error, :nif_not_loaded}

  @doc "Parses a string into an integer."
  @spec parse_int(String.t()) :: {:ok, integer()} | {:error, rust_error()}
  def parse_int(_input), do: {:error, :nif_not_loaded}

  @doc "Reads a required integer key from a map."
  @spec map_get_int(map(), String.t()) :: {:ok, integer()} | {:error, rust_error()}
  def map_get_int(_map, _key), do: {:error, :nif_not_loaded}

  @doc "Runs a compute-heavy operation guarded by `catch_unwind`."
  @spec safe_compute(boolean()) :: {:ok, integer()} | {:error, rust_error()}
  def safe_compute(_should_panic), do: {:error, :nif_not_loaded}
end