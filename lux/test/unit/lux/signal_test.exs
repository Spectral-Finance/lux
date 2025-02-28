defmodule Lux.SignalTest do
  use UnitCase, async: true

  alias Lux.Signal

  describe "new/1" do
    test "creates a signal from a map" do
      attrs = %{
        id: "test-1",
        schema_id: Schema1,
        payload: %{message: "Hello"},
        metadata: %{created_at: "2024-01-01"},
        sender: "agent-1",
        recipient: "agent-2"
      }

      signal = Signal.new(attrs)

      assert %Signal{} = signal
      assert signal.id == "test-1"
      assert signal.schema_id == Schema1
      assert signal.payload == %{message: "Hello"}
      assert signal.metadata == %{created_at: "2024-01-01"}
      assert signal.sender == "agent-1"
      assert signal.recipient == "agent-2"
    end

    test "initializes empty metadata when not provided" do
      attrs = %{
        id: "test-1",
        schema_id: Schema1,
        payload: %{message: "Hello"}
      }

      signal = Signal.new(attrs)
      assert signal.metadata == %{}
      assert signal.sender == nil
      assert signal.recipient == nil
    end
  end

  describe "when using Signal" do
    test "creates a signal with schema reference" do
      defmodule BasicSignal do
        @moduledoc false
        use Lux.Signal,
          schema_id: TestSignalSchema
      end

      {:ok, signal} = BasicSignal.new(%{payload: %{message: "Hello"}})

      assert %Signal{} = signal
      assert is_binary(signal.id)
      assert signal.schema_id == TestSignalSchema
      assert signal.payload == %{message: "Hello"}
      assert signal.metadata == %{}
      assert signal.sender == nil
      assert signal.recipient == nil
    end

    test "creates a signal with sender and recipient" do
      defmodule RoutedSignal do
        @moduledoc false
        use Lux.Signal,
          schema_id: TestSignalSchema
      end

      {:ok, signal} =
        RoutedSignal.new(%{payload: %{message: "hello"}, sender: "agent-1", recipient: "agent-2"})

      assert signal.payload.message == "hello"
      assert signal.sender == "agent-1"
      assert signal.recipient == "agent-2"
    end

    defmodule ValidatedSignal do
      @moduledoc false
      use Lux.Signal,
        schema_id: TestSignalSchema
    end

    test "supports content validation via SignalSchema" do
      assert {:ok,
              %Lux.Signal{
                schema_id: TestSignalSchema,
                payload: %{message: "Valid"}
              }} = ValidatedSignal.new(%{payload: %{message: "Valid"}})

      assert {:error, "Invalid content"} = ValidatedSignal.new(%{payload: %{wrong: "Invalid"}})
    end

    test "provides schema helpers" do
      defmodule SignalWithHelpers do
        @moduledoc false
        use Lux.Signal,
          schema_id: TestSignalSchema
      end

      assert SignalWithHelpers.schema_id() == TestSignalSchema
    end
  end
end
