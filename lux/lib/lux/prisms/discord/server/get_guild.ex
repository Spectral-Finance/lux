defmodule Lux.Prisms.Discord.Server.GetGuild do
  @moduledoc """
  A prism for retrieving a Discord guild by ID.

  Returns guild information including name, icon, features, member count, etc.
  """

  use Lux.Prism,
    name: "Get Discord Guild",
    description: "Retrieves a Discord guild by ID",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to retrieve",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string},
        name: %{type: :string},
        icon: %{type: :string, nullable: true},
        icon_hash: %{type: :string, nullable: true},
        splash: %{type: :string, nullable: true},
        discovery_splash: %{type: :string, nullable: true},
        owner_id: %{type: :string},
        region: %{type: :string},
        afk_channel_id: %{type: :string, nullable: true},
        afk_timeout: %{type: :integer},
        widget_enabled: %{type: :boolean},
        widget_channel_id: %{type: :string, nullable: true},
        verification_level: %{type: :integer},
        default_message_notifications: %{type: :integer},
        explicit_content_filter: %{type: :integer},
        roles: %{type: :array},
        emojis: %{type: :array},
        features: %{type: :array},
        mfa_level: %{type: :integer},
        application_id: %{type: :string, nullable: true},
        system_channel_id: %{type: :string, nullable: true},
        system_channel_flags: %{type: :integer},
        rules_channel_id: %{type: :string, nullable: true},
        max_presences: %{type: :integer, nullable: true},
        max_members: %{type: :integer},
        vanity_url_code: %{type: :string, nullable: true},
        description: %{type: :string, nullable: true},
        banner: %{type: :string, nullable: true},
        premium_tier: %{type: :integer},
        premium_subscription_count: %{type: :integer},
        preferred_locale: %{type: :string},
        public_updates_channel_id: %{type: :string, nullable: true},
        max_video_channel_users: %{type: :integer},
        approximate_member_count: %{type: :integer},
        approximate_presence_count: %{type: :integer},
        welcome_screen: %{type: :object, nullable: true},
        nsfw_level: %{type: :integer}
      }
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Retrieves a Discord guild by ID.
  """
  def handler(params, agent) do
    with {:ok, guild_id} <- Lux.Prisms.Discord.Helpers.validate_string(params, :guild_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} getting guild #{guild_id}")

      case Client.request(:get, "/guilds/#{guild_id}") do
        {:ok, guild} ->
          Logger.info("Retrieved guild #{guild[\"name\"]} (#{guild_id})")
          {:ok, guild}
        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to get guild #{guild_id}: #{inspect(error)}")
          {:error, error}
        {:error, error} ->
          Logger.error("Failed to get guild #{guild_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end
end