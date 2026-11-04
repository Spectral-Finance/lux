defmodule Lux.Prisms.Discord.Signals.ValidateSignalPrism do
  @moduledoc """
  A prism that validates a Discord signal payload against its configured SignalSchema.
  """

  use Lux.Prism,
    name: "Discord Validate Signal Prism",
    description: "Validates a Discord signal payload against schema constraints",
    input_schema: %{
      type: :object,
      properties: %{
        schema_type: %{
          type: :string,
          enum: ["message", "interaction", "presence", "voice"]
        },
        payload: %{type: :object}
      },
      required: ["schema_type", "payload"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        valid: %{type: :boolean},
        schema_type: %{type: :string},
        errors: %{type: :array}
      },
      required: ["valid", "schema_type"]
    }

  @impl true
  def handler(inputs, _context) do
    type = Map.get(inputs, "schema_type") || Map.get(inputs, :schema_type, "message")
    payload = Map.get(inputs, "payload") || Map.get(inputs, :payload, %{})

    errors = validate_fields(type, payload)

    if errors == [] do
      {:ok, %{valid: true, schema_type: type, errors: []}}
    else
      {:ok, %{valid: false, schema_type: type, errors: errors}}
    end
  end

  defp validate_fields("message", payload) do
    if Map.has_key?(payload, "channel_id") or Map.has_key?(payload, :channel_id) do
      []
    else
      ["Missing required field: channel_id"]
    end
  end

  defp validate_fields("interaction", payload) do
    cond do
      not (Map.has_key?(payload, "interaction_id") or Map.has_key?(payload, :interaction_id)) ->
        ["Missing required field: interaction_id"]

      not (Map.has_key?(payload, "type") or Map.has_key?(payload, :type)) ->
        ["Missing required field: type"]

      true ->
        []
    end
  end

  defp validate_fields("presence", payload) do
    if Map.has_key?(payload, "user_id") or Map.has_key?(payload, :user_id) do
      []
    else
      ["Missing required field: user_id"]
    end
  end

  defp validate_fields("voice", payload) do
    if Map.has_key?(payload, "user_id") or Map.has_key?(payload, :user_id) do
      []
    else
      ["Missing required field: user_id"]
    end
  end

  defp validate_fields(_other, _payload), do: []
end
