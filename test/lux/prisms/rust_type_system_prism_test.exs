defmodule Test.Lux.Rust.TypeSystemPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Rust.MyStruct
  alias Lux.Rust.AutoStruct

  test "convert primitive types to and from Rust" do
    elixir_value = "value1"
    rust_value = MyStruct.to_rust_field1(%MyStruct{field1: elixir_value})
    assert elixir_value == MyStruct.from_rust_field1(rust_value)
  end

  test "convert structs to and from Rust" do
    elixir_struct = %AutoStruct{field1: "value1", field2: "value2"}
    rust_value = AutoStruct.to_rust_field1(elixir_struct)
    assert elixir_struct == AutoStruct.from_rust_field1(rust_value)
  end

  test "convert enums to and from Rust" do
    # Assuming there's an enum in Rust with variants `Variant1` and `Variant2`
    rust_value = :rust_nifs.to_rust_enum("Variant1")
    assert "Variant1" == :rust_nifs.from_rust_enum(rust_value)
  end

  test "convert nested types to and from Rust" do
    elixir_nested_struct = %AutoStruct{field1: "value1", field2: %MyStruct{field1: "nested_value1"}}
    rust_value = AutoStruct.to_rust_field2(elixir_nested_struct)
    assert elixir_nested_struct == AutoStruct.from_rust_field2(rust_value)
  end
end