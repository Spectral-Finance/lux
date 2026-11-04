defmodule Lux.Rust.Types.SchemaGeneratorTest do
  use UnitCase, async: true

  alias Lux.Rust.Types.SchemaGenerator

  doctest Lux.Rust.Types.SchemaGenerator

  describe "generate/2" do
    test "generates a struct with serde derives" do
      assert {:ok, code} =
               SchemaGenerator.generate({:struct, [id: :u64, name: :string]}, name: "User")

      assert code ==
               "#[derive(Serialize, Deserialize)]\npub struct User {\n    pub id: u64,\n    pub name: String,\n}"
    end

    test "generates an enum with unit, newtype and tuple variants" do
      variants = [red: :unit, rgb: {:tuple, [:u8, :u8, :u8]}, named: :string]

      assert {:ok, code} = SchemaGenerator.generate({:enum, variants}, name: "Color")

      assert code ==
               "#[derive(Serialize, Deserialize)]\npub enum Color {\n    Red,\n    Rgb((u8, u8, u8)),\n    Named(String),\n}"
    end

    test "generates nested container types" do
      fields = [tags: {:vec, {:option, :string}}, index: {:map, :string, :i32}]

      assert {:ok, code} = SchemaGenerator.generate({:struct, fields}, name: "Doc")
      assert code =~ "pub tags: Vec<Option<String>>,"
      assert code =~ "pub index: HashMap<String, i32>,"
    end

    test "generates empty types" do
      assert SchemaGenerator.generate({:struct, []}, name: "Empty") ==
               {:ok, "#[derive(Serialize, Deserialize)]\npub struct Empty {}"}

      assert SchemaGenerator.generate({:enum, []}, name: "Never") ==
               {:ok, "#[derive(Serialize, Deserialize)]\npub enum Never {}"}
    end

    test "applies derive, rename_all and tagging options" do
      opts = [name: "Event", derive: ["Clone", "Debug"], rename_all: "snake_case", tag: :internal]
      assert {:ok, code} = SchemaGenerator.generate({:struct, [id: :u64]}, opts)

      assert code =~ "#[derive(Serialize, Deserialize, Clone, Debug)]"
      assert code =~ "#[serde(rename_all = \"snake_case\")]"
      assert code =~ "#[serde(tag = \"type\")]"
    end

    test "supports adjacently tagged enums" do
      opts = [name: "Message", tag: {:adjacent, "kind", "payload"}]
      assert {:ok, code} = SchemaGenerator.generate({:enum, [ping: :unit]}, opts)
      assert code =~ "#[serde(tag = \"kind\", content = \"payload\")]"
    end

    test "requires a name" do
      assert SchemaGenerator.generate({:struct, [x: :i64]}) == {:error, :missing_name}
    end

    test "rejects unsupported specifications" do
      assert SchemaGenerator.generate({:nope, :x}, name: "Bad") ==
               {:error, {:unsupported_type, {:nope, :x}}}

      assert SchemaGenerator.generate({:struct, [x: {:nope, :x}]}, name: "Bad") ==
               {:error, {:unsupported_type, {:nope, :x}}}
    end
  end

  describe "generate_all/1" do
    test "renders multiple definitions separated by blank lines" do
      specs = [
        {{:struct, [id: :u64]}, [name: "User"]},
        {{:enum, [on: :unit, off: :unit]}, [name: "Switch"]}
      ]

      assert {:ok, code} = SchemaGenerator.generate_all(specs)
      assert code =~ "pub struct User"
      assert code =~ "pub enum Switch"
      assert code =~ "\n\n"
    end
  end

  describe "to_rust_type/1" do
    test "maps specifications to their Rust representation" do
      assert SchemaGenerator.to_rust_type(:bool) == {:ok, "bool"}
      assert SchemaGenerator.to_rust_type({:option, :string}) == {:ok, "Option<String>"}
      assert SchemaGenerator.to_rust_type({:vec, :i32}) == {:ok, "Vec<i32>"}
      assert SchemaGenerator.to_rust_type({:tuple, [:i64, :string]}) == {:ok, "(i64, String)"}
      assert SchemaGenerator.to_rust_type({:map, :string, :i64}) == {:ok, "HashMap<String, i64>"}
    end
  end

  describe "rust_type/1 inference" do
    test "infers Rust types from runtime values" do
      assert SchemaGenerator.rust_type(1) == {:ok, "i64"}
      assert SchemaGenerator.rust_type(2.0) == {:ok, "f64"}
      assert SchemaGenerator.rust_type("s") == {:ok, "String"}
      assert SchemaGenerator.rust_type([1, 2]) == {:ok, "Vec<i64>"}
      assert SchemaGenerator.rust_type(%{"k" => true}) == {:ok, "HashMap<String, bool>"}
    end
  end
end
