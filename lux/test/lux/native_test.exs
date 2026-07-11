defmodule Lux.NativeTest do
  use ExUnit.Case, async: true
  alias Lux.Native
  alias Lux.Native.ComplexData

  describe "basic type conversions" do
    test "reverse_string/1 correctly handles string conversion" do
      assert Native.reverse_string("hello") == "olleh"
      assert Native.reverse_string("elixir and rust") == "tsur dna rixile"
    end

    @tag timeout: 10_000
    test "reverse_string/1 handles large inputs robustly without crashing (DirtyCpu test)" do
      large_string = String.duplicate("abcdefghij", 1_000_000) # 10MB string
      expected = String.duplicate("jihgfedcba", 1_000_000)
      assert Native.reverse_string(large_string) == expected
    end
  end

  describe "error handling framework" do
    test "parse_number/1 returns ok tuple for valid numbers" do
      assert {:ok, 42.5} = Native.parse_number("42.5")
      assert {:ok, 100.0} = Native.parse_number("100")
    end

    test "parse_number/1 returns error tuple for invalid inputs" do
      assert {:error, :invalid_type} = Native.parse_number("not_a_number")
    end
  end

  describe "complex data structure mapping" do
    test "process_payload/1 handles maps properly" do
      payload = %{id: 1, data: "test", is_active: true}
      assert {:ok, "test_processed"} = Native.process_payload(payload)
      
      inactive_payload = %{id: 2, data: "test", is_active: false}
      assert {:error, "payload_inactive"} = Native.process_payload(inactive_payload)
    end

    test "transform_complex/1 modifies and maps structs robustly" do
      data = %ComplexData{
        name: "lux",
        items: ["init"],
        metadata: %{id: 10, data: "meta", is_active: true}
      }

      assert {:ok, result} = Native.transform_complex(data)
      
      assert result.__struct__ == ComplexData
      assert result.name == "LUX"
      assert result.items == ["init", "Native Item"]
      assert result.metadata.id == 10
    end
  end
end
