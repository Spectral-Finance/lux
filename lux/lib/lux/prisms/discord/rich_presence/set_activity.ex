defmodule Lux.Prisms.Discord.RichPresence.SetActivity do
  @moduledoc """
  A prism for setting rich presence activity with full Discord integration.

  Supports all Discord activity types: playing, streaming, listening, watching, competing.
  Includes timestamps, party, assets, buttons, and secrets for rich presence.
  """

  use Lux.Prism,
    name: "Set Discord Rich Presence Activity",
    description: "Sets a rich presence activity with full Discord integration",
    input_schema: %{
      type: :object,
      properties: %{
        type: %{
          type: :integer,
          description: "Activity type: 0=playing, 1=streaming, 2=listening, 3=watching, 5=competing",
          enum: [0, 1, 2, 3, 5]
        },
        name: %{
          type: :string,
          description: "Activity name (1-128 characters)",
          minLength: 1,
          maxLength: 128
        },
        details: %{
          type: :string,
          description: "What the player is currently doing (max 128 chars)",
          maxLength: 128
        },
        state: %{
          type: :string,
          description: "User's current party status (max 128 chars)",
          maxLength: 128
        },
        url: %{
          type: :string,
          description: "Stream URL (required for streaming type)",
          format: "uri"
        },
        timestamps: %{
          type: :object,
          properties: %{
            start: %{type: :integer, description: "Unix timestamp (seconds) when activity started"},
            end: %{type: :integer, description: "Unix timestamp (seconds) when activity ends"}
          }
        },
        assets: %{
          type: :object,
          properties: %{
            large_image: %{type: :string, description: "Large image asset key"},
            large_text: %{type: :string, description: "Large image tooltip text"},
            small_image: %{type: :string, description: "Small image asset key"},
            small_text: %{type: :string, description: "Small image tooltip text"}
          }
        },
        party: %{
          type: :object,
          properties: %{
            id: %{type: :string, description: "Party ID"},
            size: %{
              type: :array,
              items: %{type: :integer},
              minItems: 2,
              maxItems: 2,
              description: "[current_size, max_size]"
            }
          }
        },
        buttons: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              label: %{type: :string, maxLength: 32},
              url: %{type: :string, format: "uri"}
            },
            required: ["label", "url"]
          },
          maxItems: 2
        },
        instance: %{
          type: :boolean,
          description: "Whether this activity is an instance",
          default: true
        }
      },
      required: ["type", "name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        updated: %{
          type: :boolean,
          description: "Whether presence was successfully updated"
        },
        activity: %{
          type: :object,
          properties: %{
            name: %{type: :string},
            type: %{type: :integer},
            state: %{type: :string}
          }
        }
      },
      required: ["updated"]
    }

  alias Lux.Integrations.Discord.Client
  alias Lux.Prisms.Discord.Helpers
  require Logger

  @doc """
  Sets a rich presence activity.

  Returns {:ok, %{updated: true, activity: ...}} on success.
  Returns {:error, reason} on failure.
  """
  @spec handler(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def handler(params, agent) do
    with {:ok, type} <- Helpers.validate_integer(params, "type"),
         {:ok, name} <- Helpers.validate_string(params, "name"),
         {:ok, details} <- Helpers.validate_string(params, "details", nil),
         {:ok, state} <- Helpers.validate_string(params, "state", nil),
         {:ok, url} <- Helpers.validate_string(params, "url", nil),
         {:ok, timestamps} <- Helpers.optional(params, "timestamps"),
         {:ok, assets} <- Helpers.optional(params, "assets"),
         {:ok, party} <- Helpers.optional(params, "party"),
         {:ok, buttons} <- Helpers.optional(params, "buttons"),
         {:ok, instance} <- Helpers.validate_boolean(params, "instance", true) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} setting rich presence: #{name} (type: #{type})")

      # Validate streaming type requires URL
      if type == 1 and (url == nil or url == "") do
        return {:error, "Streaming activity type requires a URL"}
      end

      body = %{
        "activities" => [%{
          "type" => type,
          "name" => name,
          "details" => details,
          "state" => state,
          "url" => url,
          "timestamps" => timestamps,
          "assets" => assets,
          "party" => party,
          "buttons" => buttons,
          "instance" => instance
        } |> Enum.filter(fn {_, v} -> v != nil end) |> Enum.into(%{})],
        "status" => "online",
        "afk" => false
      }

      case Client.request(:patch, "/users/@me/settings", %{json: body}) do
        {:ok, %{"activities" => [%{ "name" => name, "type" => type, "state" => state } = activity]}} ->
          Logger.info("Successfully set rich presence activity: #{name}")
          {:ok, %{updated: true, activity: %{name: name, type: type, state: state}}}

        {:ok, _} ->
          {:ok, %{updated: true, activity: %{name: name, type: type, state: state}}}

        {:error, {status, %{"message" => message}}} ->
          {:error, {status, message}}

        {:error, error} ->
          {:error, error}
      end
    end
  end
end