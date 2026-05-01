defmodule Lux.Prisms.Discord.Members.UserProfile do
  @moduledoc """
  A prism for retrieving a Discord user's profile information.

  ## Examples

      iex> UserProfile.handler(%{
      ...>   user_id: "222222222222222222",
      ...>   guild_id: "111111111111111111"
      ...> }, %{name: "Agent"})
      {:ok, %{
        user_id: "222222222222222222",
        username: "example_user",
        display_name: "Example User",
        roles: ["333333333333333333"],
        joined_at: "2024-01-01T00:00:00.000000+00:00"
      }}
  """

  use Lux.Prism,
    name: "Get Discord User Profile",
    description: "Retrieves profile information for a Discord user",
    input_schema: %{
      type: :object,
      properties: %{
        user_id: %{
          type: :string,
          description: "The ID of the user to look up",
          pattern: "^[0-9]{17,20}$"
        },
        guild_id: %{
          type: :string,
          description: "Optional server ID to get server-specific profile (roles, join date)",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        user_id: %{type: :string, description: "The user's ID"},
        username: %{type: :string, description: "The user's username"},
        display_name: %{type: :string, description: "The user's display name"},
        avatar_url: %{type: :string, description: "URL of the user's avatar"},
        roles: %{type: :array, description: "List of role IDs (guild context only)"},
        joined_at: %{type: :string, description: "When the user joined the server (guild context only)"}
      },
      required: ["user_id"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, user_id} <- validate_param(params, :user_id),
         {:ok, guild_id} <- validate_optional_param(params, :guild_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} fetching profile for user #{user_id}")

      with {:ok, user} <- fetch_user(user_id),
           {:ok, member} <- fetch_guild_member(guild_id, user_id) do
        profile = build_profile(user, member, guild_id)
        Logger.info("Successfully retrieved profile for user #{user_id}")
        {:ok, profile}
      else
        {:ok, user} when is_map(user) and guild_id == nil ->
          profile = build_profile(user, nil, nil)
          {:ok, profile}
        error ->
          Logger.error("Failed to fetch user profile: #{inspect(error)}")
          error
      end
    end
  end

  defp fetch_user(user_id) do
    Client.request(:get, "/users/#{user_id}", %{})
  end

  defp fetch_guild_member(nil, _user_id), do: {:ok, nil}
  defp fetch_guild_member(guild_id, user_id) do
    case Client.request(:get, "/guilds/#{guild_id}/members/#{user_id}", %{}) do
      {:ok, member} -> {:ok, member}
      error -> error
    end
  end

  defp build_profile(user, nil, _guild_id) do
    %{
      user_id: user["id"],
      username: user["username"],
      display_name: user["global_name"] || user["username"],
      avatar_url: build_avatar_url(user["id"], user["avatar"]),
      roles: [],
      joined_at: nil
    }
  end

  defp build_profile(user, member, _guild_id) do
    %{
      user_id: user["id"],
      username: user["username"],
      display_name: member["nick"] || user["global_name"] || user["username"],
      avatar_url: build_avatar_url(user["id"], user["avatar"]),
      roles: member["roles"] || [],
      joined_at: member["joined_at"]
    }
  end

  defp build_avatar_url(user_id, avatar_hash) when is_binary(avatar_hash) do
    "https://cdn.discordapp.com/avatars/#{user_id}/#{avatar_hash}.png"
  end
  defp build_avatar_url(_user_id, _avatar_hash), do: nil

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_optional_param(params, key, default \\ nil) do
    case Map.get(params, key, default) do
      nil -> {:ok, nil}
      value -> {:ok, value}
    end
  end
end
