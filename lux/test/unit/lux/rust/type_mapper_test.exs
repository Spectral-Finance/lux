defmodule Lux.Rust.TypeMapperTest do
  use UnitCase, async: true

  alias Lux.Rust.TypeMapper

  @research_artifact {:struct, :research_artifact,
                      [
                        {:id, :string},
                        {:revision, :integer},
                        {:tags, {:list, :string}},
                        {:metadata, {:map, :string}},
                        {:checksum, {:option, :string}, required: false}
                      ]}

  test "maps primitives and nested container types to Rust" do
    assert TypeMapper.rust_type(:string) == "String"
    assert TypeMapper.rust_type(:integer) == "i64"
    assert TypeMapper.rust_type({:option, :string}) == "Option<String>"
    assert TypeMapper.rust_type({:list, {:option, :integer}}) == "Vec<Option<i64>>"

    assert TypeMapper.rust_type({:map, :string, {:list, :boolean}}) ==
             "std::collections::HashMap<String, Vec<bool>>"
  end

  test "describes structs with field metadata" do
    descriptor = TypeMapper.describe(@research_artifact)

    assert descriptor.kind == :struct
    assert descriptor.name == "ResearchArtifact"
    assert descriptor.rust == "ResearchArtifact"
    assert Enum.map(descriptor.fields, & &1.rust_name) == ~w(id revision tags metadata checksum)
    assert Enum.find(descriptor.fields, &(&1.elixir_name == :checksum)).required? == false
  end

  test "renders serde struct and enum definitions" do
    struct_code =
      TypeMapper.struct_definition(:research_artifact, [
        {:id, :string},
        {:source_url, :string, serde_name: "sourceUrl"},
        {:checksum, {:option, :string}, required: false}
      ])

    assert struct_code =~ "pub struct ResearchArtifact"
    assert struct_code =~ "#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]"
    assert struct_code =~ ~s|#[serde(rename = "sourceUrl")]|
    assert struct_code =~ ~s|#[serde(default, skip_serializing_if = "Option::is_none")]|
    assert struct_code =~ "pub checksum: Option<String>,"

    enum_code =
      TypeMapper.enum_definition(:artifact_state, [
        :draft,
        :published,
        {:rejected, :string}
      ])

    assert enum_code =~ "pub enum ArtifactState"
    assert enum_code =~ ~s|#[serde(tag = "type", content = "data")]|
    assert enum_code =~ "Draft,"
    assert enum_code =~ "Rejected(String),"
  end

  test "encodes and decodes struct payloads through serde names" do
    value = %{
      id: "artifact-1",
      revision: 3,
      tags: ["paper", "dataset"],
      metadata: %{doi: "10.000/example"},
      checksum: nil
    }

    assert {:ok, encoded} = TypeMapper.encode_value(@research_artifact, value)

    assert encoded == %{
             "id" => "artifact-1",
             "revision" => 3,
             "tags" => ["paper", "dataset"],
             "metadata" => %{"doi" => "10.000/example"},
             "checksum" => nil
           }

    assert {:ok, decoded} = TypeMapper.decode_value(@research_artifact, encoded)

    assert decoded == %{
             id: "artifact-1",
             revision: 3,
             tags: ["paper", "dataset"],
             metadata: %{"doi" => "10.000/example"},
             checksum: nil
           }
  end

  test "encodes and decodes tagged enum payloads" do
    state = {:enum, :artifact_state, [:draft, :published, {:rejected, :string}]}

    assert {:ok, %{"type" => "draft"}} = TypeMapper.encode_value(state, :draft)

    assert {:ok, %{"type" => "rejected", "data" => "invalid checksum"}} =
             TypeMapper.encode_value(state, {:rejected, "invalid checksum"})

    assert {:ok, :published} = TypeMapper.decode_value(state, %{"type" => "published"})

    assert {:ok, {:rejected, "invalid checksum"}} =
             TypeMapper.decode_value(state, %{
               "type" => "rejected",
               "data" => "invalid checksum"
             })
  end

  test "returns useful errors for invalid payloads" do
    assert {:error, {:missing_field, :id}} =
             TypeMapper.encode_value(@research_artifact, %{revision: 1, tags: [], metadata: %{}})

    assert {:error, {:type_mismatch, :integer, "3"}} =
             TypeMapper.encode_value(:integer, "3")

    assert {:error, {:unknown_variant, :unknown}} =
             TypeMapper.encode_value({:enum, :state, [:ready]}, :unknown)
  end
end
