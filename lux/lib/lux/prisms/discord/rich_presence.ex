defmodule Lux.Prisms.Discord.RichPresence do
  @moduledoc """
  Set custom rich presence activity for the bot on Discord.

  Uses the Discord API to update bot presence via PATCH request.
  Requires the Presence intent.

  ## Examples

      iex> RichPresence.set_presence(%{activity: "playing", name: "Lux Bot", state: "v1.0"}, %{name: "Agent"})
      {:ok, %{updated: true, activity: "Lux Bot"}}

      iex> RichPresence.set_presence(%{activity: "unknown_type"}, %{name: "Agent"})
      {:error, "Unknown activity type: unknown_type"}
  """

  use Lux.Prism,
    name: "Update Discord Rich Presence",
    description: "Sets custom rich presence activity for the bot on Discord",
    input_schema: %{
      type: :object,
      properties: %{
        activity: %{
          type: :string,
          description: "Activity type: playing, streaming, listening, watching, competing",
          enum: ["playing", "streaming", "listening", "watching", "competing"]
        },
        name: %{
          type: :string,
          description: "Activity name (1-128 characters)",
          minLength: 1,
          maxLength: 128
        },
        state: %{
          type: :string,
          description: "Custom status text (max 128 characters, or nil)",
          maxLength: 128
        },
        status: %{
          type: :string,
          description: "Bot status: online, idle, dnd, invisible",
          enum: ["online", "idle", "dnd", "invisible"],
          default: "online"
        }
      },
      required: ["activity", "name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        updated: %{
          type: :boolean,
          description: "Whether presence was successfully updated"
        },
        activity: %{
          type: :string,
          description: "The activity name that was set"
        },
        status: %{
          type: :string,
          description: "The bot status that was set"
        }
      },
      required: ["updated"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @activity_types %{
    "playing" => 0,
    "streaming" => 1,
    "listening" => 2,
    "watching" => 3,
    "competing" => 5
  }

  @doc """
  Sets the bot's rich presence activity.

  Returns {:ok, %{updated: true, activity: name, status: status}} on success.
  Returns {:error, reason} on failure.
  """
  @spec set_presence(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def set_presence(params, agent) do
    with {:ok, activity} <- validate_activity(params),
         {:ok, name} <- validate_name(params),
         {:ok, status} <- validate_status(params) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} setting presence: #{name} (#{activity})")

      type_code = Map.fetch!(@activity_types, activity)
      state = Map.get(params, :state)

      body = %{
        "since" => 0,
        "activities" => [
          %{
            "name" => name,
            "type" => type_code
          }
        ],
        "status" => status,
        "afk" => false
      }

      case Client.request(:patch, "/users/@me/presence", %{json: body}) do
        {:ok, _} ->
          Logger.info("Successfully set presence: #{name} (#{activity})")
          {:ok, %{updated: true, activity: name, status: status}}

        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to set presence: #{inspect(error)}")
          {:error, "Discord API error #{status}: #{message}"}

        {:error, error} ->
          Logger.error("Failed to set presence: #{inspect(error)}")
          {:error, "Request failed: #{inspect(error)}"}
      end
    end
  end

  defp validate_activity(params) do
    case Map.fetch(params, :activity) do
      {:ok, activity} when activity in Map.keys(@activity_types) -> {:ok, activity}
      {:ok, activity} -> {:error, "Unknown activity type: #{activity}"}
      :error -> {:error, "Missing :activity parameter"}
    end
  end

  defp validate_name(params) do
    case Map.fetch(params, :name) do
      {:ok, name} when is_binary(name) and byte_size(name) >= 1 and byte_size(name) <= 128 -> {:ok, name}
      {:ok, name} when is_binary(name) -> {:error, "Activity name must be 1-128 characters (got #{byte_size(name)})"}
      :error -> {:error, "Missing :name parameter"}
    end
  end

  defp validate_status(params) do
    status = Map.get(params, :status, "online")
    if status in ["online", "idle", "dnd", "invisible"], do: {:ok, status}, else: {:error, "Invalid status: #{status}"}
  end
end
