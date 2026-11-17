defmodule Lux.Prisms.Discord.EventHandling do
  @moduledoc """
  Manages Discord scheduled events and notifications.
  """
  use Lux.Prism

  @description "Schedules and manages Discord server events."

  def run(%{action: :schedule, guild_id: gid, name: name, start_time: start_time} = params) do
    event_params = %{
      name: name,
      scheduled_start_time: start_time,
      entity_type: params[:type] || :external,
      privacy_level: 2, # Guild Only
      location: params[:location]
    }
    DiscordClient.create_guild_scheduled_event(gid, event_params)
  end

  def run(%{action: :list, guild_id: gid}) do
    DiscordClient.list_guild_scheduled_events(gid)
  end

  def run(%{action: :cancel, guild_id: gid, event_id: eid}) do
    DiscordClient.delete_guild_scheduled_event(gid, eid)
  end
end
