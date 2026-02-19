defmodule Lux.Schemas.EventMonitor.ContractEventSchemaTest do
  use UnitCase, async: true

  alias Lux.Schemas.EventMonitor.ContractEventSchema

  describe "schema" do
    test "has a name" do
      assert ContractEventSchema.name() == "ContractEvent"
    end

    test "has a schema definition" do
      schema = ContractEventSchema.schema()
      assert is_map(schema)
      assert schema["type"] == "object"
      assert Map.has_key?(schema["properties"], "address")
      assert Map.has_key?(schema["properties"], "chain_id")
      assert Map.has_key?(schema["properties"], "block_number")
      assert Map.has_key?(schema["properties"], "transaction_hash")
    end

    test "required fields are correct" do
      schema = ContractEventSchema.schema()
      required = schema["required"]

      assert "address" in required
      assert "chain_id" in required
      assert "block_number" in required
      assert "transaction_hash" in required
    end

    test "view returns schema struct" do
      view = ContractEventSchema.view()
      assert %Lux.SignalSchema{} = view
      assert view.name == "ContractEvent"
      assert view.version == "1.0.0"
      assert "web3" in view.tags
      assert "events" in view.tags
    end
  end

  describe "validate/1" do
    test "validates a valid contract event signal" do
      signal = %Lux.Signal{
        id: "test-signal",
        payload: %{
          "address" => "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
          "chain_id" => 1,
          "block_number" => 18_000_000,
          "transaction_hash" => "0xabc123",
          "event_name" => "Transfer",
          "log_index" => 0,
          "decoded_params" => %{
            "from" => "0x1234",
            "to" => "0x5678",
            "value" => 1_000_000
          }
        },
        schema_id: ContractEventSchema
      }

      assert {:ok, _validated} = ContractEventSchema.validate(signal)
    end

    test "rejects signal missing required fields" do
      signal = %Lux.Signal{
        id: "test-signal",
        payload: %{
          "event_name" => "Transfer"
        },
        schema_id: ContractEventSchema
      }

      assert {:error, _errors} = ContractEventSchema.validate(signal)
    end
  end
end
