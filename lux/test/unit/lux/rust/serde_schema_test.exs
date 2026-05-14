defmodule Lux.Rust.SerdeSchemaTest do
  use UnitCase, async: true

  alias Lux.Rust.SerdeSchema

  test "maps primitive and container descriptors to Rust types" do
    assert SerdeSchema.rust_type(SerdeSchema.primitive(:string)) == "String"

    assert SerdeSchema.rust_type(SerdeSchema.option(SerdeSchema.primitive(:integer))) ==
             "Option<i64>"

    assert SerdeSchema.rust_type(SerdeSchema.list(SerdeSchema.primitive(:boolean))) ==
             "Vec<bool>"

    assert SerdeSchema.rust_type(
             SerdeSchema.map_of(SerdeSchema.primitive(:string), SerdeSchema.primitive(:json))
           ) == "std::collections::BTreeMap<String, serde_json::Value>"
  end

  test "generates Serde-ready Rust struct definitions" do
    schema =
      SerdeSchema.struct(
        :trade_intent,
        [
          SerdeSchema.field(:user_id, SerdeSchema.primitive(:integer), rename: "userId"),
          SerdeSchema.field(:memo, SerdeSchema.option(SerdeSchema.primitive(:string)),
            skip_nil?: true
          )
        ],
        rename_all: "camelCase"
      )

    definition = SerdeSchema.rust_definition(schema)

    assert definition =~ "pub struct TradeIntent"
    assert definition =~ "#[serde(rename_all = \"camelCase\")]"
    assert definition =~ "#[serde(rename = \"userId\")]"
    assert definition =~ "pub user_id: i64"
    assert definition =~ "pub memo: Option<String>"
  end

  test "encodes and decodes struct values with renamed fields and defaults" do
    schema =
      SerdeSchema.struct(:trade_intent, [
        SerdeSchema.field(:user_id, SerdeSchema.primitive(:integer), rename: "userId"),
        SerdeSchema.field(:symbol, SerdeSchema.primitive(:string)),
        SerdeSchema.field(:metadata, SerdeSchema.primitive(:json), default: %{})
      ])

    assert {:ok, encoded} =
             SerdeSchema.encode(schema, %{user_id: 7, symbol: "ETH-USD"})

    assert encoded == %{"metadata" => %{}, "symbol" => "ETH-USD", "userId" => 7}

    assert {:ok, decoded} = SerdeSchema.decode(schema, encoded)
    assert decoded == %{metadata: %{}, symbol: "ETH-USD", user_id: 7}
  end

  test "returns explicit errors for missing fields and type mismatches" do
    schema =
      SerdeSchema.struct(:trade_intent, [
        SerdeSchema.field(:amount, SerdeSchema.primitive(:float))
      ])

    assert {:error, %{code: :missing_field, field: "amount"}} = SerdeSchema.encode(schema, %{})

    assert {:error, %{code: :type_mismatch, field: "amount"}} =
             SerdeSchema.encode(schema, %{amount: "12.4"})
  end

  test "encodes and decodes adjacently tagged enum variants" do
    schema =
      SerdeSchema.enum(:order_event, [
        SerdeSchema.variant(:accepted, [
          SerdeSchema.field(:order_id, SerdeSchema.primitive(:string), rename: "orderId")
        ]),
        SerdeSchema.variant(:rejected, SerdeSchema.primitive(:string)),
        SerdeSchema.variant(:heartbeat)
      ])

    assert {:ok, accepted} =
             SerdeSchema.encode(schema, {:accepted, %{order_id: "ord_1"}})

    assert accepted == %{"data" => %{"orderId" => "ord_1"}, "type" => "accepted"}

    assert {:ok, {:accepted, %{order_id: "ord_1"}}} = SerdeSchema.decode(schema, accepted)

    assert {:ok, %{"data" => "bad checksum", "type" => "rejected"}} =
             SerdeSchema.encode(schema, {:rejected, "bad checksum"})

    assert {:ok, %{"type" => "heartbeat"}} = SerdeSchema.encode(schema, {:heartbeat, nil})
  end

  test "generates Serde enum definitions" do
    schema =
      SerdeSchema.enum(
        :order_event,
        [
          SerdeSchema.variant(:accepted, [
            SerdeSchema.field(:order_id, SerdeSchema.primitive(:string), rename: "orderId")
          ]),
          SerdeSchema.variant(:rejected, SerdeSchema.primitive(:string))
        ],
        tag: "kind",
        content: "payload"
      )

    definition = SerdeSchema.rust_definition(schema)

    assert definition =~ "pub enum OrderEvent"
    assert definition =~ "#[serde(tag = \"kind\", content = \"payload\")]"
    assert definition =~ "Accepted {"
    assert definition =~ "pub order_id: String"
    assert definition =~ "Rejected(String)"
  end

  test "exports a manifest for Rust code generation" do
    schema =
      SerdeSchema.struct(:trade_intent, [
        SerdeSchema.field(:user_id, SerdeSchema.primitive(:integer), rename: "userId")
      ])

    manifest = SerdeSchema.manifest(schema)

    assert manifest.name == "TradeIntent"

    assert manifest.fields == [
             %{name: "user_id", required?: true, rust_type: "i64", wire_name: "userId"}
           ]

    assert :serde_integration in manifest.coverage
    assert :bidirectional_serialization in manifest.coverage
  end

  test "infers descriptors for JSON-compatible values" do
    assert SerdeSchema.infer("lux") |> SerdeSchema.rust_type() == "String"
    assert SerdeSchema.infer([1, 2, 3]) |> SerdeSchema.rust_type() == "Vec<i64>"
    assert SerdeSchema.infer(%{"data" => true}) |> SerdeSchema.rust_type() =~ "BTreeMap"
  end
end
