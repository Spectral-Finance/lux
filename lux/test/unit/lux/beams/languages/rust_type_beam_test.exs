defmodule Lux.Beams.Languages.RustTypeBeamTest do
  use UnitAPICase, async: true

  alias Lux.Beams.Languages.Rust.Types.TypeSerializationBeam

  describe "TypeSerializationBeam" do
    test "verifies beam definition and metadata" do
      assert TypeSerializationBeam.name() == "Rust Type Serialization Pipeline"
      assert is_map(TypeSerializationBeam.input_schema())
      assert is_map(TypeSerializationBeam.output_schema())
      assert TypeSerializationBeam.input_schema().required == ["data"]
    end

    test "executes full pipeline sequence" do
      inputs = %{
        data: %{"tx_hash" => "0xabc", "gas_used" => 21000},
        type_name: "TxReceipt",
        fields_schema: %{"tx_hash" => "string", "gas_used" => "integer"}
      }

      assert {:ok, result, execution_log} = TypeSerializationBeam.run(inputs)
      assert execution_log.status == :completed
      assert result.is_match == true
      assert String.contains?(result.rust_code, "pub struct TxReceipt {")
    end
  end
end
