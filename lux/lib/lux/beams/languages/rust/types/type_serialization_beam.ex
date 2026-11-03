defmodule Lux.Beams.Languages.Rust.Types.TypeSerializationBeam do
  @moduledoc """
  A beam orchestrating type serialization, roundtrip integrity validation,
  and Rust schema generation:
  1. Serializes Elixir data into Serde JSON representation.
  2. Deserializes the representation back to Elixir terms.
  3. Verifies zero loss of fidelity across roundtrips.
  4. Generates corresponding Rust struct code with Serde attributes.

  ## Example Usage

  ```elixir
  {:ok, result, execution_log} = Lux.Beams.Languages.Rust.Types.TypeSerializationBeam.run(%{
    data: %{id: "user_123", balance: 500.0, verified: true},
    type_name: "UserProfile",
    fields_schema: %{"id" => "string", "balance" => "float", "verified" => "boolean"}
  })
  ```
  """

  use Lux.Beam,
    name: "Rust Type Serialization Pipeline",
    description: "Orchestrates bidirectional serialization, validation, and schema generation for Rust",
    input_schema: %{
      type: :object,
      properties: %{
        data: %{
          type: :object,
          description: "Data structure to serialize"
        },
        type_name: %{
          type: :string,
          description: "Name of the target Rust type",
          default: "CustomPayload"
        },
        fields_schema: %{
          type: :object,
          description: "Type mapping definition"
        }
      },
      required: ["data"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        is_match: %{type: :boolean},
        rust_code: %{type: :string}
      },
      required: ["is_match", "rust_code"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Languages.Rust.Types.CustomSchemaPrism
  alias Lux.Prisms.Languages.Rust.Types.DeserializePrism
  alias Lux.Prisms.Languages.Rust.Types.SerializePrism
  alias Lux.Prisms.Languages.Rust.Types.ValidatePrism

  sequence do
    # Step 1: Serialize to Serde JSON
    step(:serialize, SerializePrism, %{
      payload: [:input, :data],
      format: "json"
    })

    # Step 2: Deserialize back
    step(:deserialize, DeserializePrism, %{
      payload: [:steps, :serialize, :serialized]
    })

    # Step 3: Validate roundtrip match
    step(:validate, ValidatePrism, %{
      original: [:input, :data],
      roundtripped: [:steps, :deserialize, :deserialized]
    })

    # Step 4: Generate Rust struct code
    step(:generate_schema, CustomSchemaPrism, %{
      kind: "struct",
      name: [:input, :type_name],
      definition: [:input, :fields_schema]
    })
  end
end
