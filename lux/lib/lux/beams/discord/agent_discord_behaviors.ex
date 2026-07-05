defmodule Lux.Beams.Discord.AgentDiscordBehaviors do
  use Lux.Beam,
    name: "Agent Discord Behaviors",
    description: "Combines discord management capabilities for an agent"

  # This beam would orchestrate the use of prisms and lenses based on intent.
  # For now, we expose the capabilities for agents to use.

  def capabilities do
    [
      Lux.Prisms.Discord.Guild.LeaveGuild,
      Lux.Prisms.Discord.Role.CreateRole,
      Lux.Prisms.Discord.Role.AddMemberRole,
      Lux.Prisms.Discord.Member.CreateDM,
      Lux.Prisms.Discord.Member.KickMember,
      Lux.Prisms.Discord.Messages.SendMessage,
      Lux.Prisms.Discord.Channels.CreateChannel,
      Lux.Lenses.Discord.Guild.GetGuild,
      Lux.Lenses.Discord.Member.GetMember
    ]
  end
end\n