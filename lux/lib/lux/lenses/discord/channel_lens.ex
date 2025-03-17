defmodule Lux.Lenses.Discord.ChannelLens do
  @moduledoc """
  A lens for reading Discord channel information.

  This lens provides functionality to:
  1. Get channel information using GET /channels/{channel.id}
  2. List channels in a guild using GET /guilds/{guild.id}/channels
  3. Get channel permissions (included in both responses)

  ## Authentication
  Requires a Discord bot token in the application configuration:
  ```elixir
  config :lux, :discord_token, "your-bot-token"
  ```

  ## Rate Limiting
  Discord API has rate limits per route. This lens handles rate limiting by:
  - Respecting the retry_after header
  - Following the global rate limit
  - Using proper request headers

  ## Examples
      # Get a specific channel
      iex> Lux.Lenses.Discord.ChannelLens.focus(%{
      ...>   channel_id: "987654321"
      ...> }, %{})
      {:ok, %{channel: %{"id" => "987654321", "name" => "example-channel", ...}}}

      # List channels in a guild
      iex> Lux.Lenses.Discord.ChannelLens.focus(%{
      ...>   guild_id: "123456789"
      ...> }, %{})
      {:ok, %{channels: [%{"id" => "987654321", "name" => "general", ...}]}}

  ## Error Cases
      # Invalid channel ID
      iex> Lux.Lenses.Discord.ChannelLens.focus(%{channel_id: "invalid"}, %{})
      {:error, %{type: "discord_api_error", code: 50004, message: "Invalid channel ID"}}

      # Missing permissions
      iex> Lux.Lenses.Discord.ChannelLens.focus(%{guild_id: "123456789"}, %{})
      {:error, %{type: "discord_api_error", code: 50001, message: "Missing Access"}}

      # Rate limited
      iex> Lux.Lenses.Discord.ChannelLens.focus(%{channel_id: "123456789"}, %{})
      {:error, %{type: "rate_limit", retry_after: 5000}}
  """

  use Lux.Lens,
    name: "Discord Channel Lens",
    description: "Reads Discord channel information",
    url: "https://discord.com/api/v10",  # Base URL, actual endpoints handled in before_focus
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &__MODULE__.add_auth_header/1
    },
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to list channels from",
          pattern: "^[0-9]{17,20}$"
        },
        channel_id: %{
          type: :string,
          description: "The ID of the specific channel to get information about",
          pattern: "^[0-9]{17,20}$"
        }
      },
      oneOf: [
        %{required: ["guild_id"]},
        %{required: ["channel_id"]}
      ]
    }

  require Logger

  @doc """
  Adds Discord bot token to request headers.
  """
  def add_auth_header(lens) do
    token = Application.fetch_env!(:lux, :discord_token)
    %{lens | headers: lens.headers ++ [{"Authorization", "Bot #{token}"}]}
  end

  @doc """
  Prepares the request URL based on the parameters.
  If channel_id is provided, fetches a specific channel using GET /channels/{channel.id}.
  Otherwise, lists all channels in the guild using GET /guilds/{guild.id}/channels.
  """
  def before_focus(params) do
    base_url = "https://discord.com/api/v10"

    url = if Map.has_key?(params, :channel_id) do
      "#{base_url}/channels/#{params.channel_id}"
    else
      "#{base_url}/guilds/#{params.guild_id}/channels"
    end

    %{url: url}
  end

  @doc """
  Handles the Discord API response.
  """
  @impl true
  def after_focus(response) when is_list(response) do
    {:ok, %{channels: response}}
  end

  @impl true
  def after_focus(%{"id" => _} = response) do
    {:ok, %{channel: response}}
  end

  @impl true
  def after_focus(%{"code" => code, "message" => message}) do
    {:error, %{type: "discord_api_error", code: code, message: message}}
  end

  @impl true
  def after_focus(%{"retry_after" => retry_after}) do
    {:error, %{type: "rate_limit", retry_after: retry_after}}
  end

  @impl true
  def after_focus(response) do
    Logger.error("Unexpected Discord API response: #{inspect(response)}")
    {:error, %{type: "unexpected_response", message: "Received unexpected response format"}}
  end

  defp lens_url do
    __MODULE__.view().url
  end
end
