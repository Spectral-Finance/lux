defmodule Lux.Rust.FFITest do
  use UnitCase, async: true

  alias Lux.Rust.FFI

  @manifest_path Path.expand("../../../../priv/rust/lux_ffi/Cargo.toml", __DIR__)

  test "reports checked-in Rust FFI project availability" do
    assert FFI.available?(manifest_path: @manifest_path)

    project = FFI.project()
    assert project.library_name == "lux_ffi"
    assert "cdylib" in project.crate_type
    assert :ffi_binding_contract in project.coverage
  end

  test "builds JSON payloads for the exported FFI function" do
    assert {:ok, request} = FFI.request(:type_of, %{"name" => "lux"})

    assert request.function == "lux_ffi_execute_json"
    assert request.free_function == "lux_ffi_free_buffer"
    assert request.payload_size == byte_size(request.payload)
    assert request.input_type == "serde_json::Map<String, Value>"

    assert Jason.decode!(request.payload) == %{
             "input" => %{"name" => "lux"},
             "operation" => "type_of"
           }
  end

  test "decodes Rust success and error envelopes" do
    assert {:ok, %{"type" => "string"}} =
             FFI.decode_response(~s({"ok":true,"value":{"type":"string"}}))

    assert {:error, %{code: "type_error", message: "expected array"}} =
             FFI.decode_response(
               ~s({"ok":false,"error":{"code":"type_error","message":"expected array"}})
             )

    assert {:error, %{code: "decode_error"}} = FFI.decode_response("not-json")
  end

  test "maps Elixir values to Rust boundary types" do
    assert FFI.rust_type(nil) == "serde_json::Value::Null"
    assert FFI.rust_type(true) == "bool"
    assert FFI.rust_type(10) == "i64"
    assert FFI.rust_type(1.5) == "f64"
    assert FFI.rust_type("lux") == "String"
    assert FFI.rust_type([1, 2]) == "Vec<serde_json::Value>"
    assert FFI.rust_type(%{"a" => 1}) == "serde_json::Map<String, Value>"
  end

  test "documents ABI symbols and memory safety contract" do
    abi = FFI.abi()
    safety = FFI.safety_contract()

    assert abi.execute.symbol == "lux_ffi_execute_json"
    assert abi.free.symbol == "lux_ffi_free_buffer"
    assert safety.ownership =~ "transfers"
    assert safety.release =~ "lux_ffi_free_buffer"
  end

  test "returns reproducible cargo command plans" do
    commands = FFI.cargo_commands(manifest_path: @manifest_path)

    assert commands.fmt == ["cargo", "fmt", "--manifest-path", @manifest_path]
    assert commands.test == ["cargo", "test", "--manifest-path", @manifest_path]
    assert commands.build == ["cargo", "build", "--release", "--manifest-path", @manifest_path]
  end
end
