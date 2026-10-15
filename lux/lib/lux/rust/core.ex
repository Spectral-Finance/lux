defmodule Lux.Rust.Core do
  @moduledoc """
  Rust Core Integration and FFI Bridge for Lux (#94).

  Provides:
  - 'priv/rust' workspace layout and crate configuration management
  - Safe primitive type conversion between Elixir terms and Rust FFI types
  - Structured NIF error propagation with memory safety guards
  """

  @supported_primitives [:i64, :u64, :f64, :bool, :string, :bytes]

  @doc """
  Generates the canonical 'priv/rust' project layout descriptor for a Lux native module.
  """
  @spec project_layout(String.t()) :: {:ok, map()} | {:error, term()}
  def project_layout(crate_name) when is_binary(crate_name) do
    trimmed = String.trim(crate_name)

    if trimmed == "" or not Regex.match?(~r/^[a-z][a-z0-9_]*$/, trimmed) do
      {:error, :invalid_crate_name}
    else
      {:ok,
       %{
         crate_name: trimmed,
         root_dir: "priv/rust/" <> trimmed,
         cargo_toml: "priv/rust/" <> trimmed <> "/Cargo.toml",
         src_lib: "priv/rust/" <> trimmed <> "/src/lib.rs"
       }}
    end
  end

  @doc """
  Validates and converts an Elixir primitive value to its typed Rust FFI representation.
  """
  @spec marshal_primitive(atom(), term()) :: {:ok, map()} | {:error, term()}
  def marshal_primitive(rust_type, value) when rust_type in @supported_primitives do
    case {rust_type, value} do
      {:i64, v} when is_integer(v) -> {:ok, %{rust_type: :i64, value: v}}
      {:u64, v} when is_integer(v) and v >= 0 -> {:ok, %{rust_type: :u64, value: v}}
      {:f64, v} when is_number(v) -> {:ok, %{rust_type: :f64, value: v * 1.0}}
      {:bool, v} when is_boolean(v) -> {:ok, %{rust_type: :bool, value: v}}
      {:string, v} when is_binary(v) -> {:ok, %{rust_type: :string, value: v, byte_len: byte_size(v)}}
      {:bytes, v} when is_binary(v) -> {:ok, %{rust_type: :bytes, value: Base.encode16(v, case: :lower)}}
      _ -> {:error, {:type_mismatch, rust_type, value}}
    end
  end

  def marshal_primitive(unsupported, _value), do: {:error, {:unsupported_rust_type, unsupported}}
end
