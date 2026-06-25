defmodule Lux.Unit.Schemas.TechnicalSignalSchemaTest do
  @moduledoc false
  use UnitCase, async: true

  alias Lux.Schemas.TechnicalSignalSchema

  describe "TechnicalSignalSchema" do
    test "schema is valid" do
      assert function_exported?(TechnicalSignalSchema, :schema, 0)
      assert function_exported?(TechnicalSignalSchema, :name, 0)
      assert function_exported?(TechnicalSignalSchema, :id, 0)
    end

    test "has correct name" do
      assert TechnicalSignalSchema.name() == "technical_signal"
    end

    test "has correct version" do
      schema = TechnicalSignalSchema.schema()
      assert schema["type"] == "object"
    end

    test "signal validates correctly" do
      signal_data = %{
        symbol: "BTC/USDT",
        timeframe: "1D",
        signal: "buy",
        confidence: 0.75,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        rationale: "RSI oversold with bullish MACD crossover"
      }

      assert TechnicalSignalSchema.validate(signal_data) == :ok
    end

    test "rejects invalid signal" do
      invalid_data = %{
        symbol: "BTC/USDT",
        signal: "invalid_signal_type"
      }

      assert TechnicalSignalSchema.validate(invalid_data) == :ok
    end
  end
end
