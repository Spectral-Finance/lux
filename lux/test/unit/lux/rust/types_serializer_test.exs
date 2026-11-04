defmodule Lux.Rust.Types.SerializerTest do
  use UnitCase, async: true

  alias Lux.Rust.Types.Serializer

  doctest Lux.Rust.Types.Serializer

  describe "happy path" do
    test "encodes and decodes primitive values" do
      assert Serializer.encode(42) == {:ok, 42}
      assert Serializer.encode(3.5) == {:ok, 3.5}
      assert Serializer.encode(true) == {:ok, true}
      assert Serializer.encode("hello") == {:ok, "hello"}
      assert Serializer.encode(nil) == {:ok, nil}

      assert Serializer.decode(42) == {:ok, 42}
      assert Serializer.decode(3.5) == {:ok, 3.5}
      assert Serializer.decode(false) == {:ok, false}
      assert Serializer.decode("hello") == {:ok, "hello"}
      assert Serializer.decode(nil) == {:ok, nil}
    end

    test "maps integers to validated signed/unsigned types" do
      assert Serializer.encode(200, :u8) == {:ok, 200}
      assert Serializer.encode(-100, :i8) == {:ok, -100}
      assert Serializer.encode(1_000_000, :i64) == {:ok, 1_000_000}
    end

    test "round trips a nested struct with tuple, vec, option and map fields" do
      type =
        {:struct,
         [
           id: :u64,
           tags: {:vec, :string},
           location: {:option, {:tuple, [:f64, :f64]}},
           meta: {:map, :string, :string}
         ]}

      value = %{id: 1, tags: ["a", "b"], location: {51.5, -0.1}, meta: %{"k" => "v"}}

      assert {:ok, wire} = Serializer.encode(value, type)

      assert wire == %{
               "id" => 1,
               "tags" => ["a", "b"],
               "location" => [51.5, -0.1],
               "meta" => %{"k" => "v"}
             }

      assert {:ok, ^value} = Serializer.decode(wire, type)
    end

    test "round trips unit and newtype enum variants" do
      type = {:enum, [red: :unit, rgb: {:tuple, [:u8, :u8, :u8]}]}

      assert Serializer.encode(:red, type) == {:ok, "Red"}
      assert Serializer.encode({:rgb, {1, 2, 3}}, type) == {:ok, %{"Rgb" => [1, 2, 3]}}
      assert Serializer.decode("Red", type) == {:ok, :red}
      assert Serializer.decode(%{"Rgb" => [1, 2, 3]}, type) == {:ok, {:rgb, {1, 2, 3}}}
    end

    test "round trips through the JSON representation" do
      type = {:struct, [name: :string, price: {:option, :f64}]}
      value = %{name: "widget", price: 9.99}

      assert {:ok, json} = Serializer.to_json(value, type)
      assert json == ~s({"name":"widget","price":9.99})
      assert Serializer.from_json(json, type) == {:ok, value}
    end

    test "round_trip/2 confirms faithful conversions" do
      type = {:map, :string, {:vec, :i64}}
      assert Serializer.round_trip(%{"a" => [1, 2]}, type) == {:ok, %{"a" => [1, 2]}}
    end
  end

  describe "null input" do
    test "nil is accepted for optional values" do
      assert Serializer.encode(nil, {:option, :i64}) == {:ok, nil}
      assert Serializer.decode(nil, {:option, :string}) == {:ok, nil}
    end

    test "nil for a required scalar is an explicit validation error" do
      assert Serializer.encode(nil, :i64) == {:error, {:unexpected_null, :i64}}
      assert Serializer.decode(nil, :bool) == {:error, {:unexpected_null, :bool}}
    end

    test "nil for a required struct field is a typed error" do
      type = {:struct, [name: :string]}
      assert Serializer.encode(%{name: nil}, type) == {:error, {:unexpected_null, :string}}
    end

    test "does not crash on nil nested inside a container" do
      assert Serializer.encode([nil, 1], {:vec, {:option, :i64}}) == {:ok, [nil, 1]}
    end
  end

  describe "empty input" do
    test "accepts empty strings, lists and maps" do
      assert Serializer.encode("", :string) == {:ok, ""}
      assert Serializer.encode([], {:vec, :i64}) == {:ok, []}
      assert Serializer.encode(%{}, {:map, :string, :i64}) == {:ok, %{}}
      assert Serializer.encode(%{}, {:struct, []}) == {:ok, %{}}
      assert Serializer.decode([], {:vec, :string}) == {:ok, []}
    end

    test "rejects empty json with a diagnostic error" do
      assert {:error, _reason} = Serializer.from_json("")
      assert {:error, _reason} = Serializer.from_json("   ")
    end

    test "rejects empty or multi-character strings for char" do
      assert Serializer.encode("", :char) == {:error, {:invalid_char, ""}}
      assert Serializer.encode("  ", :char) == {:error, {:invalid_char, "  "}}
    end
  end

  describe "boundary limits" do
    test "evaluates unsigned integer bounds strictly" do
      assert Serializer.encode(0, :u8) == {:ok, 0}
      assert Serializer.encode(255, :u8) == {:ok, 255}
      assert Serializer.encode(-1, :u8) == {:error, {:integer_out_of_range, -1}}
      assert Serializer.encode(256, :u8) == {:error, {:integer_out_of_range, 256}}
      assert Serializer.decode(255, :u8) == {:ok, 255}
      assert Serializer.decode(256, :u8) == {:error, {:integer_out_of_range, 256}}
    end

    test "evaluates signed integer bounds strictly" do
      assert Serializer.encode(-128, :i8) == {:ok, -128}
      assert Serializer.encode(127, :i8) == {:ok, 127}
      assert Serializer.encode(128, :i8) == {:error, {:integer_out_of_range, 128}}
      assert Serializer.encode(-129, :i8) == {:error, {:integer_out_of_range, -129}}
    end

    test "evaluates 64-bit unsigned maximum strictly" do
      assert Serializer.encode(18_446_744_073_709_551_615, :u64) ==
               {:ok, 18_446_744_073_709_551_615}

      assert Serializer.encode(18_446_744_073_709_551_616, :u64) ==
               {:error, {:integer_out_of_range, 18_446_744_073_709_551_616}}
    end

    test "enforces tuple arity" do
      assert Serializer.encode({1, 2}, {:tuple, [:i64, :i64]}) == {:ok, [1, 2]}

      assert Serializer.encode({1, 2}, {:tuple, [:i64, :i64, :i64]}) ==
               {:error, {:invalid_type, :tuple, {1, 2}}}

      assert Serializer.decode([1, 2], {:tuple, [:i64, :i64, :i64]}) ==
               {:error, {:invalid_type, :tuple, [1, 2]}}
    end
  end

  describe "negative / failure handling" do
    test "rejects unknown enum variants on both directions" do
      type = {:enum, [red: :unit]}

      assert Serializer.encode(:blue, type) == {:error, {:unknown_variant, "blue"}}
      assert Serializer.decode("Blue", type) == {:error, {:unknown_variant, "Blue"}}
    end

    test "rejects missing and unexpected struct fields" do
      type = {:struct, [x: :f64, y: :f64]}

      assert Serializer.encode(%{x: 1.0}, type) == {:error, {:missing_field, :y}}

      assert Serializer.encode(%{x: 1.0, y: 2.0, z: 3.0}, type) ==
               {:error, {:unexpected_field, :z}}

      assert Serializer.decode(%{"x" => 1.0}, type) == {:error, {:missing_field, :y}}
    end

    test "rejects malformed and unsupported values with typed errors" do
      assert Serializer.encode("nope", :i64) == {:error, {:invalid_type, :integer, "nope"}}
      assert Serializer.decode(<<255, 254>>, :string) == {:error, {:invalid_utf8, <<255, 254>>}}
      assert Serializer.encode(%{1 => 2}) == {:error, {:invalid_map_key, 1}}
      assert Serializer.encode(self()) == {:error, {:unsupported_type, self()}}
      assert Serializer.encode!(42) == 42
      assert_raise ArgumentError, fn -> Serializer.encode!(nil, :i64) end
    end

    test "never interns untrusted wire strings into atoms" do
      key = "brand_new_rust_key_xyz"

      assert Serializer.decode(%{key => 1}, {:map, :string, :i64}) == {:ok, %{key => 1}}
      assert_raise ArgumentError, fn -> String.to_existing_atom(key) end
    end
  end

  describe "concurrency" do
    test "concurrent encode/decode of the same type stays consistent" do
      type = {:struct, [id: :u64, tags: {:vec, :string}, status: {:option, :string}]}
      value = %{id: 7, tags: ["x", "y"], status: nil}

      results =
        1..64
        |> Task.async_stream(fn _index ->
          {:ok, wire} = Serializer.encode(value, type)
          Serializer.decode(wire, type)
        end)
        |> Enum.map(fn {:ok, result} -> result end)

      assert length(results) == 64
      assert Enum.all?(results, &(&1 == {:ok, value}))
    end
  end

  describe "regression: Rust type system and serialization" do
    test "performs a complete bidirectional complex conversion" do
      type =
        {:struct,
         [
           id: :u64,
           name: :string,
           version: :u8,
           enabled: :bool,
           tags: {:vec, :string},
           coordinates: {:option, {:tuple, [:f64, :f64]}},
           attributes: {:map, :string, :string},
           status: {:enum, [pending: :unit, active: :unit, custom: {:struct, [code: :u16]}]}
         ]}

      value = %{
        id: 18_446_744_073_709_551_615,
        name: "lux",
        version: 255,
        enabled: true,
        tags: ["rust", "elixir"],
        coordinates: {1.0, 2.0},
        attributes: %{"color" => "green"},
        status: {:custom, %{code: 200}}
      }

      assert {:ok, wire} = Serializer.encode(value, type)
      assert wire["status"] == %{"Custom" => %{"code" => 200}}
      assert Serializer.decode(wire, type) == {:ok, value}
      assert Serializer.round_trip(value, type) == {:ok, value}
    end
  end
end
