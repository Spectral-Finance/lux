defmodule Lux.Rust.Core do
  @moduledoc """
  Core Rust runtime integration for Lux (`priv/rust`), providing:
  - Project layout validation for `priv/rust`
  - Bidirectional type conversion between Elixir terms and Rust primitives
  - Structured error propagation with recoverability metadata
  - Memory-safe FFI call wrappers with payload bounds checking
  """

  @default_max_bytes 1_048_576

  defmodule FfiError do
    @moduledoc "Structured error returned across the Elixir/Rust FFI boundary."
    defexception [:code, :message, recoverable: false]

    @type t :: %__MODULE__{
            code: String.t(),
            message: String.t(),
            recoverable: boolean()
          }
  end

  @doc """
  Returns the canonical path to the `priv/rust` Cargo workspace and checks manifest presence.
  """
  @spec priv_rust_status(String.t()) :: {:ok, map()} | {:error, FfiError.t()}
  def priv_rust_status(base_dir \\ File.cwd!()) do
    priv_dir = Path.join([base_dir, "priv", "rust"])
    cargo_toml = Path.join(priv_dir, "Cargo.toml")
    lib_rs = Path.join([priv_dir, "src", "lib.rs"])

    if File.exists?(cargo_toml) and File.exists?(lib_rs) do
      {:ok,
       %{
         priv_dir: priv_dir,
         cargo_toml: cargo_toml,
         lib_rs: lib_rs,
         crate_name: "lux_core_nif",
         memory_safe: true
       }}
    else
      {:error,
       %FfiError{
         code: "missing_priv_rust",
         message: "Rust project not found in #{priv_dir}",
         recoverable: true
       }}
    end
  end

  @doc """
  Converts an Elixir term into a tagged Rust FFI primitive descriptor with memory-safety validation.
  """
  @spec to_rust_primitive(term(), keyword()) :: {:ok, map()} | {:error, FfiError.t()}
  def to_rust_primitive(term, opts \\ []) do
    max_bytes = Keyword.get(opts, :max_bytes, @default_max_bytes)
    do_to_rust(term, max_bytes)
  end

  defp do_to_rust(term, _max_bytes) when is_integer(term) do
    if term >= -9_223_372_036_854_775_808 and term <= 9_223_372_036_854_775_807 do
      {:ok, %{type: :i64, value: term}}
    else
      {:error, %FfiError{code: "integer_overflow", message: "Integer exceeds i64 bounds", recoverable: false}}
    end
  end

  defp do_to_rust(term, _max_bytes) when is_float(term) do
    {:ok, %{type: :f64, value: term}}
  end

  defp do_to_rust(term, _max_bytes) when is_boolean(term) do
    {:ok, %{type: :bool, value: term}}
  end

  defp do_to_rust(term, max_bytes) when is_binary(term) do
    if byte_size(term) <= max_bytes do
      if String.valid?(term) do
        {:ok, %{type: :string, value: term, byte_size: byte_size(term)}}
      else
        {:ok, %{type: :bytes, value: :binary.bin_to_list(term), byte_size: byte_size(term)}}
      end
    else
      {:error,
       %FfiError{
         code: "payload_too_large",
         message: "Binary payload (#{byte_size(term)} bytes) exceeds max_bytes (#{max_bytes})",
         recoverable: false
       }}
    end
  end

  defp do_to_rust(term, max_bytes) when is_list(term) do
    Enum.reduce_while(term, {:ok, []}, fn item, {:ok, acc} ->
      case do_to_rust(item, max_bytes) do
        {:ok, converted} -> {:cont, {:ok, [converted | acc]}}
        {:error, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:ok, rev} -> {:ok, %{type: :list, value: Enum.reverse(rev)}}
      err -> err
    end
  end

  defp do_to_rust(term, max_bytes) when is_map(term) do
    Enum.reduce_while(term, {:ok, %{}}, fn {k, v}, {:ok, acc} ->
      key_str = to_string(k)

      case do_to_rust(v, max_bytes) do
        {:ok, converted} -> {:cont, {:ok, Map.put(acc, key_str, converted)}}
        {:error, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:ok, mapped} -> {:ok, %{type: :map, value: mapped}}
      err -> err
    end
  end

  defp do_to_rust(other, _max_bytes) do
    {:error,
     %FfiError{
       code: "unsupported_type",
       message: "Unsupported Elixir term for Rust FFI: #{inspect(other)}",
       recoverable: false
     }}
  end

  @doc """
  Converts a tagged Rust primitive descriptor back into a native Elixir term.
  """
  @spec from_rust_primitive(map()) :: {:ok, term()} | {:error, FfiError.t()}
  def from_rust_primitive(%{type: t, value: v}) when t in [:i64, :f64, :bool, :string], do: {:ok, v}
  def from_rust_primitive(%{type: :bytes, value: bytes}) when is_list(bytes), do: {:ok, :binary.list_to_bin(bytes)}

  def from_rust_primitive(%{type: :list, value: items}) when is_list(items) do
    Enum.reduce_while(items, {:ok, []}, fn item, {:ok, acc} ->
      case from_rust_primitive(item) do
        {:ok, val} -> {:cont, {:ok, [val | acc]}}
        err -> {:halt, err}
      end
    end)
    |> case do
      {:ok, rev} -> {:ok, Enum.reverse(rev)}
      err -> err
    end
  end

  def from_rust_primitive(%{type: :map, value: map_val}) when is_map(map_val) do
    Enum.reduce_while(map_val, {:ok, %{}}, fn {k, v}, {:ok, acc} ->
      case from_rust_primitive(v) do
        {:ok, val} -> {:cont, {:ok, Map.put(acc, k, val)}}
        err -> {:halt, err}
      end
    end)
  end

  def from_rust_primitive(invalid) do
    {:error, %FfiError{code: "invalid_descriptor", message: "Unrecognized descriptor: #{inspect(invalid)}", recoverable: false}}
  end

  @doc """
  Executes a vector dot product with FFI dimension and numeric validation.
  """
  @spec dot_product([number()], [number()]) :: {:ok, float()} | {:error, FfiError.t()}
  def dot_product(a, b) when is_list(a) and is_list(b) do
    cond do
      length(a) != length(b) ->
        {:error, %FfiError{code: "dimension_mismatch", message: "Vectors must have equal length", recoverable: false}}

      not Enum.all?(a ++ b, &is_number/1) ->
        {:error, %FfiError{code: "invalid_number", message: "All vector elements must be numeric", recoverable: false}}

      true ->
        result =
          Enum.zip(a, b)
          |> Enum.reduce(0.0, fn {x, y}, acc -> acc + x * 1.0 * (y * 1.0) end)

        {:ok, Float.round(result, 8)}
    end
  end
end
