defmodule Lux.Rust.TypesTest do
  use UnitCase, async: false

  alias Lux.Rust.Types

  @moduletag :unit

  setup do
    case Types.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    :ok
  end

  # ── to_rust/2: integer types ─────────────────────────────────────────────────

  describe "to_rust/2 integer types" do
    test "converts integer to i64" do
      assert {:ok, %{type: :i64, value: 42}} = Types.to_rust(42, :i64)
    end

    test "converts negative integer to i32" do
      assert {:ok, %{type: :i32, value: -100}} = Types.to_rust(-100, :i32)
    end

    test "converts zero to u8" do
      assert {:ok, %{type: :u8, value: 0}} = Types.to_rust(0, :u8)
    end

    test "converts max u8 value" do
      assert {:ok, %{type: :u8, value: 255}} = Types.to_rust(255, :u8)
    end

    test "rejects u8 overflow" do
      assert {:error, msg} = Types.to_rust(256, :u8)
      assert msg =~ "out of range"
    end

    test "rejects negative value for unsigned type" do
      assert {:error, msg} = Types.to_rust(-1, :u32)
      assert msg =~ "out of range"
    end

    test "rejects float for integer type" do
      assert {:error, msg} = Types.to_rust(1.5, :i64)
      assert msg =~ "expected integer"
    end

    test "converts i8 boundary values" do
      assert {:ok, %{type: :i8, value: -128}} = Types.to_rust(-128, :i8)
      assert {:ok, %{type: :i8, value: 127}} = Types.to_rust(127, :i8)
      assert {:error, _} = Types.to_rust(128, :i8)
    end

    test "converts u64 large value" do
      assert {:ok, %{type: :u64, value: 18_446_744_073_709_551_615}} =
               Types.to_rust(18_446_744_073_709_551_615, :u64)
    end
  end

  # ── to_rust/2: float types ───────────────────────────────────────────────────

  describe "to_rust/2 float types" do
    test "converts float to f64" do
      assert {:ok, %{type: :f64, value: 3.14}} = Types.to_rust(3.14, :f64)
    end

    test "converts float to f32" do
      assert {:ok, %{type: :f32, value: v}} = Types.to_rust(2.5, :f32)
      assert_in_delta v, 2.5, 0.0001
    end

    test "coerces integer to float" do
      assert {:ok, %{type: :f64, value: 42.0}} = Types.to_rust(42, :f64)
    end

    test "rejects binary for float" do
      assert {:error, msg} = Types.to_rust("3.14", :f64)
      assert msg =~ "expected number"
    end
  end

  # ── to_rust/2: bool ──────────────────────────────────────────────────────────

  describe "to_rust/2 boolean" do
    test "converts true" do
      assert {:ok, %{type: :bool, value: true}} = Types.to_rust(true, :bool)
    end

    test "converts false" do
      assert {:ok, %{type: :bool, value: false}} = Types.to_rust(false, :bool)
    end

    test "rejects non-boolean" do
      assert {:error, msg} = Types.to_rust(1, :bool)
      assert msg =~ "expected boolean"
    end
  end

  # ── to_rust/2: string types ──────────────────────────────────────────────────

  describe "to_rust/2 string types" do
    test "converts binary to :string" do
      assert {:ok, %{type: :string, value: "hello"}} = Types.to_rust("hello", :string)
    end

    test "converts atom to :str" do
      assert {:ok, %{type: :str, value: "ok"}} = Types.to_rust(:ok, :str)
    end

    test "converts binary to vec_u8 as byte list" do
      assert {:ok, %{type: :vec_u8, value: [104, 105]}} = Types.to_rust("hi", :vec_u8)
    end

    test "converts byte list to vec_u8" do
      assert {:ok, %{type: :vec_u8, value: [0, 255]}} = Types.to_rust([0, 255], :vec_u8)
    end

    test "rejects out-of-range byte" do
      assert {:error, msg} = Types.to_rust([256], :vec_u8)
      assert msg =~ "0..255"
    end

    test "rejects integer for string" do
      assert {:error, _} = Types.to_rust(42, :string)
    end
  end

  # ── to_rust/2: option ────────────────────────────────────────────────────────

  describe "to_rust/2 option" do
    test "maps nil to Option::None" do
      assert {:ok, %{type: {:option, :i32}, value: nil}} = Types.to_rust(nil, {:option, :i32})
    end

    test "wraps a present value" do
      assert {:ok, %{type: {:option, :i32}, value: %{type: :i32, value: 7}}} =
               Types.to_rust(7, {:option, :i32})
    end

    test "propagates inner type error" do
      assert {:error, _} = Types.to_rust("bad", {:option, :i32})
    end
  end

  # ── to_rust/2: vec ───────────────────────────────────────────────────────────

  describe "to_rust/2 vec" do
    test "converts list of integers" do
      assert {:ok, %{type: {:vec, :i32}, value: elems}} = Types.to_rust([1, 2, 3], {:vec, :i32})
      assert length(elems) == 3
      assert Enum.map(elems, & &1.value) == [1, 2, 3]
    end

    test "converts empty list" do
      assert {:ok, %{type: {:vec, :f64}, value: []}} = Types.to_rust([], {:vec, :f64})
    end

    test "rejects non-list" do
      assert {:error, msg} = Types.to_rust(42, {:vec, :i32})
      assert msg =~ "expected list"
    end

    test "propagates element error" do
      assert {:error, _} = Types.to_rust([1, "bad", 3], {:vec, :i32})
    end
  end

  # ── to_rust/2: tuple ─────────────────────────────────────────────────────────

  describe "to_rust/2 tuple" do
    test "converts a 2-tuple" do
      assert {:ok, %{type: {:tuple, [:i32, :bool]}, value: [a, b]}} =
               Types.to_rust({1, true}, {:tuple, [:i32, :bool]})

      assert a.value == 1
      assert b.value == true
    end

    test "rejects arity mismatch" do
      assert {:error, msg} = Types.to_rust({1, 2, 3}, {:tuple, [:i32, :i32]})
      assert msg =~ "arity mismatch"
    end
  end

  # ── from_rust/1: round-trips ─────────────────────────────────────────────────

  describe "from_rust/1" do
    test "round-trips i64" do
      {:ok, typed} = Types.to_rust(99, :i64)
      assert {:ok, 99} = Types.from_rust(typed)
    end

    test "round-trips f64" do
      {:ok, typed} = Types.to_rust(2.71, :f64)
      assert {:ok, result} = Types.from_rust(typed)
      assert_in_delta result, 2.71, 0.0001
    end

    test "round-trips bool" do
      {:ok, typed} = Types.to_rust(false, :bool)
      assert {:ok, false} = Types.from_rust(typed)
    end

    test "round-trips string" do
      {:ok, typed} = Types.to_rust("world", :string)
      assert {:ok, "world"} = Types.from_rust(typed)
    end

    test "round-trips vec_u8 back to binary" do
      {:ok, typed} = Types.to_rust("hi", :vec_u8)
      assert {:ok, "hi"} = Types.from_rust(typed)
    end

    test "round-trips Option::None" do
      {:ok, typed} = Types.to_rust(nil, {:option, :i32})
      assert {:ok, nil} = Types.from_rust(typed)
    end

    test "round-trips Option with value" do
      {:ok, typed} = Types.to_rust(5, {:option, :i32})
      assert {:ok, 5} = Types.from_rust(typed)
    end

    test "round-trips vec of integers" do
      {:ok, typed} = Types.to_rust([10, 20], {:vec, :i32})
      assert {:ok, [10, 20]} = Types.from_rust(typed)
    end

    test "round-trips tuple" do
      {:ok, typed} = Types.to_rust({42, true}, {:tuple, [:i32, :bool]})
      assert {:ok, {42, true}} = Types.from_rust(typed)
    end

    test "returns error for unrecognised shape" do
      assert {:error, _} = Types.from_rust(%{not_a: :typed_value})
    end
  end

  # ── define_struct/2 and validate_struct/2 ────────────────────────────────────

  describe "define_struct/2 and validate_struct/2" do
    test "defines and validates a simple struct" do
      :ok = Types.define_struct(:rect, %{width: :f64, height: :f64})

      assert {:ok, %{width: 10.0, height: 5.0}} =
               Types.validate_struct(:rect, %{width: 10.0, height: 5.0})
    end

    test "rejects missing required field" do
      :ok = Types.define_struct(:rect2, %{width: :f64, height: :f64})

      assert {:error, msg} = Types.validate_struct(:rect2, %{width: 10.0})
      assert msg =~ "missing required field"
    end

    test "rejects field with wrong type" do
      :ok = Types.define_struct(:rect3, %{width: :f64, height: :f64})

      assert {:error, msg} = Types.validate_struct(:rect3, %{width: "bad", height: 5.0})
      assert msg =~ "rect3.width"
    end

    test "allows extra fields beyond the schema" do
      :ok = Types.define_struct(:minimal, %{id: :u32})

      assert {:ok, _} = Types.validate_struct(:minimal, %{id: 1, extra: "ignored"})
    end

    test "returns error for unknown struct" do
      assert {:error, msg} = Types.validate_struct(:nonexistent_struct_xyz, %{})
      assert msg =~ "unknown struct"
    end

    test "to_rust with {:struct, name} uses schema validation" do
      :ok = Types.define_struct(:color, %{r: :u8, g: :u8, b: :u8})

      assert {:ok, %{type: {:struct, :color}}} =
               Types.to_rust(%{r: 255, g: 128, b: 0}, {:struct, :color})
    end

    test "registered_structs includes defined names" do
      :ok = Types.define_struct(:my_unique_struct, %{val: :i32})
      assert :my_unique_struct in Types.registered_structs()
    end
  end

  # ── define_enum/2 and validate_enum/2 ────────────────────────────────────────

  describe "define_enum/2 and validate_enum/2" do
    test "validates an atom variant" do
      :ok = Types.define_enum(:direction, [:north, :south, :east, :west])
      assert {:ok, :north} = Types.validate_enum(:direction, :north)
    end

    test "validates a string variant" do
      :ok = Types.define_enum(:status, [:active, :inactive])
      assert {:ok, "active"} = Types.validate_enum(:status, "active")
    end

    test "rejects an invalid variant" do
      :ok = Types.define_enum(:color, [:red, :green, :blue])
      assert {:error, msg} = Types.validate_enum(:color, :purple)
      assert msg =~ "not a valid variant"
    end

    test "returns error for unknown enum" do
      assert {:error, msg} = Types.validate_enum(:nonexistent_enum_xyz, :value)
      assert msg =~ "unknown enum"
    end

    test "to_rust with {:enum, name} uses enum validation" do
      :ok = Types.define_enum(:side, [:buy, :sell])

      assert {:ok, %{type: {:enum, :side}, value: :buy}} =
               Types.to_rust(:buy, {:enum, :side})
    end

    test "to_rust rejects invalid enum variant" do
      :ok = Types.define_enum(:side2, [:buy, :sell])
      assert {:error, _} = Types.to_rust(:hold, {:enum, :side2})
    end

    test "registered_enums includes defined names" do
      :ok = Types.define_enum(:my_unique_enum, [:a, :b])
      assert :my_unique_enum in Types.registered_enums()
    end
  end

  # ── serialize/2 and deserialize/2 ────────────────────────────────────────────

  describe "serialize/2 and deserialize/2" do
    test "serializes a map to JSON" do
      assert {:ok, json} = Types.serialize(%{"key" => "value"})
      assert is_binary(json)
      assert json =~ "key"
    end

    test "deserializes JSON back to map" do
      assert {:ok, json} = Types.serialize(%{"x" => 1, "y" => 2})
      assert {:ok, map} = Types.deserialize(json)
      assert map["x"] == 1
      assert map["y"] == 2
    end

    test "round-trips a list via JSON" do
      assert {:ok, json} = Types.serialize([1, 2, 3])
      assert {:ok, [1, 2, 3]} = Types.deserialize(json)
    end

    test "round-trips via binary format" do
      term = {:ok, %{a: [1, 2, 3]}}
      assert {:ok, bin} = Types.serialize(term, format: :binary)
      assert {:ok, ^term} = Types.deserialize(bin, format: :binary)
    end

    test "returns error for unsupported format in serialize" do
      assert {:error, msg} = Types.serialize("data", format: :xml)
      assert msg =~ "unsupported"
    end

    test "returns error for unsupported format in deserialize" do
      assert {:error, msg} = Types.deserialize("data", format: :xml)
      assert msg =~ "unsupported"
    end

    test "returns error for invalid JSON in deserialize" do
      assert {:error, msg} = Types.deserialize("{not valid json}")
      assert msg =~ "deserialization failed"
    end

    test "serializes nested structures" do
      data = %{"users" => [%{"id" => 1, "name" => "Alice"}, %{"id" => 2, "name" => "Bob"}]}
      assert {:ok, json} = Types.serialize(data)
      assert {:ok, decoded} = Types.deserialize(json)
      assert length(decoded["users"]) == 2
    end
  end

  # ── char type ────────────────────────────────────────────────────────────────

  describe "to_rust/2 char" do
    test "accepts valid unicode codepoint" do
      assert {:ok, %{type: :char, value: 65}} = Types.to_rust(65, :char)
    end

    test "rejects out-of-range codepoint" do
      assert {:error, _} = Types.to_rust(0x110000, :char)
    end

    test "rejects non-integer for char" do
      assert {:error, _} = Types.to_rust("A", :char)
    end
  end

  # ── map type ─────────────────────────────────────────────────────────────────

  describe "to_rust/2 and from_rust/1 map" do
    test "converts a string-keyed map" do
      assert {:ok, typed} = Types.to_rust(%{"a" => 1}, {:map, :string, :i32})
      assert {:ok, result} = Types.from_rust(typed)
      assert result["a"] == 1
    end
  end
end
