defmodule Lux.Rust.FFI do
  @moduledoc """
  Core Rust FFI contract for Lux.

  The companion crate in `priv/rust/lux_ffi` exposes a C ABI that accepts JSON
  bytes and returns an owned response buffer. This module keeps the Elixir side
  deterministic: it builds payloads, documents the ABI, decodes responses, and
  exposes type/error metadata without loading a native library at compile time.
  """

  @crate_path Path.expand("../../../priv/rust/lux_ffi", __DIR__)
  @manifest_path Path.join(@crate_path, "Cargo.toml")

  @coverage [
    :rust_project_structure,
    :ffi_binding_contract,
    :type_conversion,
    :error_propagation,
    :memory_safety,
    :cargo_build_integration
  ]

  @doc "Returns true when the Rust FFI crate is present."
  @spec available?(keyword()) :: boolean()
  def available?(opts \\ []) do
    manifest_path = Keyword.get(opts, :manifest_path, @manifest_path)
    lib_path = manifest_path |> Path.dirname() |> Path.join("src/lib.rs")

    File.exists?(manifest_path) and File.exists?(lib_path)
  end

  @doc "Returns the crate paths used by the Rust FFI integration."
  @spec project() :: map()
  def project do
    %{
      crate_path: @crate_path,
      manifest_path: @manifest_path,
      library_name: "lux_ffi",
      crate_type: ["cdylib", "rlib"],
      coverage: @coverage
    }
  end

  @doc "Builds the JSON payload passed to `lux_ffi_execute_json`."
  @spec request(atom() | String.t(), term()) :: {:ok, map()} | {:error, map()}
  def request(operation, input) do
    payload = %{
      "operation" => to_string(operation),
      "input" => input
    }

    case Jason.encode(payload) do
      {:ok, json} ->
        {:ok,
         %{
           function: "lux_ffi_execute_json",
           free_function: "lux_ffi_free_buffer",
           payload: json,
           payload_size: byte_size(json),
           input_type: rust_type(input)
         }}

      {:error, error} ->
        {:error, %{code: "encode_error", message: Exception.message(error)}}
    end
  end

  @doc "Decodes the JSON response produced by the Rust FFI crate."
  @spec decode_response(binary()) :: {:ok, term()} | {:error, map()}
  def decode_response(response) when is_binary(response) do
    case Jason.decode(response) do
      {:ok, %{"ok" => true, "value" => value}} ->
        {:ok, value}

      {:ok, %{"ok" => false, "error" => %{"code" => code, "message" => message}}} ->
        {:error, %{code: code, message: message}}

      {:ok, other} ->
        {:error, %{code: "invalid_response", message: inspect(other)}}

      {:error, error} ->
        {:error, %{code: "decode_error", message: Exception.message(error)}}
    end
  end

  @doc "Maps JSON-compatible Elixir values to their Rust boundary type."
  @spec rust_type(term()) :: String.t()
  def rust_type(nil), do: "serde_json::Value::Null"
  def rust_type(value) when is_boolean(value), do: "bool"
  def rust_type(value) when is_integer(value), do: "i64"
  def rust_type(value) when is_float(value), do: "f64"
  def rust_type(value) when is_binary(value), do: "String"
  def rust_type(value) when is_list(value), do: "Vec<serde_json::Value>"
  def rust_type(value) when is_map(value), do: "serde_json::Map<String, Value>"
  def rust_type(_value), do: "unsupported"

  @doc "Returns the C ABI exported by the Rust crate."
  @spec abi() :: map()
  def abi do
    %{
      execute: %{
        symbol: "lux_ffi_execute_json",
        signature: "extern \"C\" fn(*const u8, usize) -> LuxFfiBuffer",
        input: "UTF-8 JSON bytes: {\"operation\": string, \"input\": Value}",
        output: "owned LuxFfiBuffer containing {\"ok\": boolean, ...}"
      },
      free: %{
        symbol: "lux_ffi_free_buffer",
        signature: "extern \"C\" fn(LuxFfiBuffer)",
        responsibility: "caller must free every non-empty response buffer exactly once"
      }
    }
  end

  @doc "Documents memory and error guarantees for native callers."
  @spec safety_contract() :: map()
  def safety_contract do
    %{
      null_input: "null input pointers return an invalid_input error buffer",
      ownership: "Rust transfers response buffer ownership to caller",
      release: "caller releases response memory with lux_ffi_free_buffer",
      panics: "FFI boundary catches malformed input as JSON error responses",
      scheduler: "Elixir module does not load or execute native code during compile"
    }
  end

  @doc "Returns reproducible Cargo commands for the checked-in crate."
  @spec cargo_commands(keyword()) :: map()
  def cargo_commands(opts \\ []) do
    manifest_path = Keyword.get(opts, :manifest_path, @manifest_path)

    %{
      fmt: ["cargo", "fmt", "--manifest-path", manifest_path],
      test: ["cargo", "test", "--manifest-path", manifest_path],
      build: ["cargo", "build", "--release", "--manifest-path", manifest_path]
    }
  end
end
