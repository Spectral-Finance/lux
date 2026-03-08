defmodule Lux.Signals.Discord.InteractionSignal do
  @moduledoc "Discord interaction signal: slash commands, buttons, select menus, modals."

  defstruct [:type, :name, :data, :user, :channel_id, :guild_id, :token, :metadata, :timestamp]

  @interaction_types [:slash_command, :button, :select_menu, :modal, :context_menu]

  def new(attrs) when is_map(attrs) do
    type = attrs[:type] || attrs["type"]
    if type in @interaction_types do
      {:ok, %__MODULE__{
        type: type,
        name: attrs[:name] || attrs["name"],
        data: attrs[:data] || attrs["data"] || %{},
        user: attrs[:user] || attrs["user"],
        channel_id: attrs[:channel_id],
        guild_id: attrs[:guild_id],
        token: attrs[:token],
        metadata: attrs[:metadata],
        timestamp: DateTime.utc_now()
      }}
    else
      {:error, :invalid_interaction_type}
    end
  end

  def to_discord(%__MODULE__{} = signal) do
    %{
      "type" => type_to_int(signal.type),
      "data" => %{"name" => signal.name, "options" => signal.data},
      "channel_id" => signal.channel_id,
      "guild_id" => signal.guild_id
    }
  end

  def from_discord(payload) when is_map(payload) do
    new(%{
      type: int_to_type(payload["type"]),
      name: get_in(payload, ["data", "name"]),
      data: get_in(payload, ["data", "options"]) || %{},
      user: payload["member"] || payload["user"],
      channel_id: payload["channel_id"],
      guild_id: payload["guild_id"],
      token: payload["token"]
    })
  end

  def interaction_types, do: @interaction_types

  defp type_to_int(:slash_command), do: 2
  defp type_to_int(:button), do: 3
  defp type_to_int(:select_menu), do: 3
  defp type_to_int(:modal), do: 5
  defp type_to_int(:context_menu), do: 2
  defp type_to_int(_), do: 0

  defp int_to_type(2), do: :slash_command
  defp int_to_type(3), do: :button
  defp int_to_type(5), do: :modal
  defp int_to_type(_), do: :slash_command
end
