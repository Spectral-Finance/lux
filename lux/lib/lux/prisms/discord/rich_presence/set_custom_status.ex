defmodule Lux.Prisms.Discord.RichPresence.SetCustomStatus do
  @moduledoc """
  A prism for setting a custom status on Discord.

  Allows setting custom status text with emoji and expiration.
  """

  use Lux.Prism,
    name: "Set Discord Custom Status",
    description: "Sets a custom status for the bot on Discord",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{
          type: :string,
          description: "Custom status text (max 128 characters)",
          maxLength: 128
        },
        emoji_name: %{
          type: :string,
          description: "Emoji name for the status"
        },
        emoji_id: %{
          type: :string,
          description: "Custom emoji ID (for animated/custom emojis)",
          pattern: "^[0-9]{17,20}$"
        },
        emoji_animated: %{
          type: :boolean,
          description: "Whether the emoji is animated",
          default: false
        },
        expires_at: %{
          type: :string,
          description: "ISO 8601 timestamp when status expires",
          format: "date-time"
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        updated: %{
          type: :boolean,
          description: "Whether custom status was successfully updated"
        },
        custom_status: %{
          type: :object,
          properties: %{
            text: %{type: :string},
            emoji_name: %{type: :string},
            emoji_id: %{type: :string},
            expires_at: %{type: :string}
          }
        }
      },
      required: ["updated"]
    }

  alias Lux.Integrations.Discord.Client
  alias Lux.Prisms.Discord.Helpers
  require Logger

  @doc """
  Sets a custom status for the bot.

  Returns {:ok, %{updated: true, custom_status: ...}} on success.
  Returns {:error, reason} on failure.
  """
  @spec handler(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def handler(params, agent) do
    with {:ok, text} <- Helpers.validate_string(params, "text", ""),
         {:ok, emoji_name} <- Helpers.validate_string(params, "emoji_name", nil),
         {:ok, emoji_id} <- Helpers.validate_string(params, "emoji_id", nil),
         {:ok, emoji_animated} <- Helpers.validate_boolean(params, "emoji_animated", false),
         {:ok, expires_at} <- Helpers.validate_string(params, "expires_at", nil) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} setting custom status: #{text}")

      body = %{
        "custom_status" => %{
          "text" => text,
          "emoji_name" => emoji_name,
          "emoji_id" => emoji_id,
          "emoji_animated" => emoji_animated,
          "expires_at" => expires_at
        }
        |> Enum.filter(fn {_, v} -> v != nil and v != "" end)
        |> Enum.into(%{})
      }

      case Client.request(:patch, "/users/@me/settings", %{json: body}) do
        {:ok, %{"custom_status" => custom_status}} ->
          Logger.info("Successfully set custom status")
          {:ok, %{updated: true, custom_status: custom_status}}

        {:error, {status, %{"message" => message}}} ->
          {:error, {status, message}}

        {:error, error} ->
          {:error, error}
      end
    end
  end
end