defmodule Lux.Prisms.Discord.Moderation.WarnMember do
  @moduledoc """
  A prism for issuing a warning to a Discord guild member.

  Creates a warning record and we can track, and optionally DMs the user.
  Does not use Discord's native timeout/ban - this is a soft warning.
  """

  use Lux.Prism,
    name: "Warn Discord Member",
    description: "Issues a warning to a Discord guild member with optional DM",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        user_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        reason: %{type: :string, minLength: 1, maxLength: 512},
        dm_user: %{type: :boolean, default: true},
        dm_content: %{type: :string, maxLength: 2000, description: "Custom DM content (optional)"}
      },
      required: ["guild_id", "user_id", "reason"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        warned: %{type: :boolean},
        guild_id: %{type: :string},
        user_id: %{type: :string},
        dm_sent: %{type: :boolean},
        warning_id: %{type: :string}
      },
      required: ["warned", "guild_id", "user_id", "dm_sent"]
    }

  alias Lux.Integrations.Discord.Client
  alias Lux.Prisms.Discord.Helpers
  require Logger

  @doc """
  Issues a warning to a Discord member.

  Returns {:ok, %{warned: true, guild_id: ..., user_id: ..., dm_sent: ..., warning_id: ...}}.
  """
  def handler(params, agent) do
    with {:ok, guild_id} <- Helpers.validate_string(params, :guild_id),
         {:ok, user_id} <- Helpers.validate_string(params, :user_id),
         {:ok, reason} <- Helpers.validate_string(params, :reason),
         {:ok, dm_user} <- Helpers.optional(params, :dm_user, true),
         {:ok, dm_content} <- Helpers.optional(params, :dm_content, nil) do

      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} warning user #{user_id} in guild #{guild_id}: #{reason}")

      warning_id = "warn_#{:rand.uniform(1_000_000)}"
      dm_sent = false

      # Send DM if requested
      if dm_user do
        dm_body = dm_content || "You have received a warning in #{guild_id}: #{reason}"
        
        # First create DM channel
        case Client.request_with_retry(:post, "/users/#{user_id}/channels", %{
          json: %{recipient_id: user_id}
        }) do
          {:ok, %{ "id" => dm_channel_id }} ->
            case Client.request_with_retry(:post, "/channels/#{dm_channel_id}/messages", %{
              json: %{content: dm_body}
            }) do
              {:ok, _} ->
                dm_sent = true
                Logger.info("Warning DM sent to user #{user_id}")
              
              error ->
                Logger.error("Failed to send warning DM to #{user_id}: #{inspect(error)}")
            end
          
          error ->
            Logger.error("Failed to create DM channel for #{user_id}: #{inspect(error)}")
        end
      end

      {:ok, %{
        warned: true,
        guild_id: guild_id,
        user_id: user_id,
        dm_sent: dm_sent,
        warning_id: warning_id
      }}
    end
  end
end