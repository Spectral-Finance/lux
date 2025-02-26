defmodule Lux.Signal do
  @moduledoc """
  Represents a signal that can be sent between agents.
  Signals are the primary means of communication between agents.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          payload: map(),
          sender: String.t() | nil,
          recipient: String.t() | nil,
          timestamp: DateTime.t(),
          metadata: map(),
          schema_id: module() | nil
        }

  defstruct id: nil,
            payload: %{},
            sender: nil,
            recipient: nil,
            timestamp: nil,
            metadata: %{},
            schema_id: nil

  defmacro __using__(opts) do
    quote do
      defstruct [
        :id,
        :payload,
        :sender,
        :recipient,
        :timestamp,
        :metadata,
        :schema_id
      ]

      @schema_module unquote(opts[:schema_id])

      def new(attrs) when is_map(attrs) do
        signal =
          Lux.Signal
          |> struct(
            Map.merge(attrs, %{
              id: attrs[:id] || Lux.UUID.generate(),
              timestamp: DateTime.utc_now(),
              metadata: attrs[:metadata] || %{},
              schema_id: @schema_module,
              payload: Map.get(attrs, :payload, %{})
            })
          )
          |> @schema_module.validate()
      end

      def schema_id, do: @schema_module
    end
  end

  @doc """
  Creates a new signal from a map of attributes.
  """
  def new(attrs) when is_map(attrs) do
    struct(
      __MODULE__,
      Map.merge(attrs, %{
        id: attrs[:id] || Lux.UUID.generate(),
        timestamp: attrs[:timestamp] || DateTime.utc_now(),
        metadata: attrs[:metadata] || %{},
        payload: attrs[:payload] || %{},
        schema_id: attrs[:schema_id]
      })
    )
  end

  @doc """
  Validates a signal against a signal schema.
  """
  def validate(%__MODULE__{} = _signal, _schema) do
    :ok
  end
end
