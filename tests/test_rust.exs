defmodule Tests.Rust do
  use ExUnit.Case

  test "convert elixir to rust" do
        import Lux.Rust.MyStruct
        import Rust.TestingLib
        rust_value = Lux.Rust.MyStruct.to_rust_field1("value1")
        assert rust_value == :erlang.nif_call(:rust_nifs, :to_rust_field1, ["value1"])
      end

      test "convert rust to elixir" do
        rust_value = "value2"
        elixir_value = Lux.Rust.MyStruct.from_rust_field1(rust_value)
        assert elixir_value == %Lux.Rust.MyStruct{field1: :erlang.nif_call(:rust_nifs, :from_rust_field1, ["value2"]), field2: nil}
      end
end