defmodule Lux.RustTest do
  use ExUnit.Case

  test "round-trip serialization of Rust data" do
    rust_data = %{"key" => "value"}
    serialized = Lux.Serialization.serialize(rust_data, :rust)
    deserialized = Lux.Serialization.deserialize(serialized, :rust)

    assert rust_data == deserialized
  end
end

def setup do
  # Initialize Rust environment here
  :ok
end