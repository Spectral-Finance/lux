defmodule Lux.Prisms.Telegram.Interactive.SendLocation do
  @moduledoc """
  A prism for sending locations via the Telegram Bot API.

  This prism provides a simple interface to send location information to Telegram chats.
  It supports both static locations and live location sharing with customizable period.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /sendLocation
  - Supports required parameters (chat_id, latitude, longitude) and optional parameters
  - Support for live location sharing with the live_period parameter
  - Returns the sent message data on success
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Send a static location
      iex> SendLocation.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   latitude: 37.7749,
      ...>   longitude: -122.4194
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 42, chat_id: 123_456_789, latitude: 37.7749, longitude: -122.4194}}

      # Send a live location that updates for 60 minutes
      iex> SendLocation.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   latitude: 37.7749,
      ...>   longitude: -122.4194,
      ...>   live_period: 3600
      ...> }, %{name: "Agent"})
      {:ok, %{sent: true, message_id: 42, chat_id: 123_456_789, latitude: 37.7749, longitude: -122.4194, live_period: 3600}}
  """

  use Lux.Prism,
    name: "Send Telegram Location",
    description: "Sends location information via the Telegram Bot API, with support for live location sharing",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        latitude: %{
          type: :number,
          description: "Latitude of the location"
        },
        longitude: %{
          type: :number,
          description: "Longitude of the location"
        },
        horizontal_accuracy: %{
          type: :number,
          description: "The radius of uncertainty for the location, measured in meters; 0-1500"
        },
        live_period: %{
          type: :integer,
          description: "Period in seconds for which the location will be updated (see Live Locations, should be between 60 and 86_400)"
        },
        heading: %{
          type: :integer,
          description: "For live locations, a direction in which the user is moving, in degrees. Must be between 1 and 360 if specified"
        },
        proximity_alert_radius: %{
          type: :integer,
          description: "For live locations, a maximum distance for proximity alerts about approaching another chat member, in meters"
        },
        disable_notification: %{
          type: :boolean,
          description: "Sends the message silently. Users will receive a notification with no sound"
        },
        protect_content: %{
          type: :boolean,
          description: "Protects the contents of the sent message from forwarding and saving"
        },
        reply_to_message_id: %{
          type: :integer,
          description: "If the message is a reply, ID of the original message"
        },
        allow_sending_without_reply: %{
          type: :boolean,
          description: "Pass True if the message should be sent even if the specified replied-to message is not found"
        },
        reply_markup: %{
          type: :object,
          description: "Additional interface options. A JSON-serialized object for an inline keyboard, custom reply keyboard, instructions to remove reply keyboard or to force a reply from the user"
        }
      },
      required: ["chat_id", "latitude", "longitude"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{
          type: :boolean,
          description: "Whether the location was successfully sent"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the sent message"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Identifier of the target chat"
        },
        latitude: %{
          type: :number,
          description: "Latitude of the sent location"
        },
        longitude: %{
          type: :number,
          description: "Longitude of the sent location"
        },
        live_period: %{
          type: :integer,
          description: "Period in seconds for which the location will be updated (if it's a live location)"
        }
      },
      required: ["sent", "message_id", "latitude", "longitude"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to send a location to a Telegram chat.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Supports both static and live location sharing
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, latitude} <- validate_param(params, :latitude, :number),
         {:ok, longitude} <- validate_param(params, :longitude, :number),
         :ok <- validate_live_period(params) do

      agent_name = agent[:name] || "Unknown Agent"

      # Determine if it's a live location or static location
      is_live = Map.has_key?(params, :live_period)
      location_type = if is_live, do: "live location", else: "location"

      Logger.info("Agent #{agent_name} sending #{location_type} to chat #{chat_id}")

      # Build the request body
      request_body = Map.take(params, [:chat_id, :latitude, :longitude,
                              :horizontal_accuracy, :live_period, :heading,
                              :proximity_alert_radius, :disable_notification,
                              :protect_content, :reply_to_message_id,
                              :allow_sending_without_reply, :reply_markup])

      # Prepare request options
      request_opts = %{json: request_body}

      case Client.request(:post, "/sendLocation", request_opts) do
        {:ok, %{"result" => result}} when is_map(result) ->
          Logger.info("Successfully sent #{location_type} to chat #{chat_id}")

          # Extract live_period for the response if it exists
          live_period = Map.get(params, :live_period)

          {:ok, %{
            sent: true,
            message_id: result["message_id"],
            chat_id: chat_id,
            latitude: latitude,
            longitude: longitude,
            live_period: live_period
          }}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to send location: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to send location: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to send location: #{inspect(error)}"}
      end
    end
  end

  defp validate_param(params, key, type \\ :any)
  defp validate_param(params, key, :number) do
    case Map.fetch(params, key) do
      {:ok, value} when is_number(value) -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_param(params, key, _type) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      {:ok, value} when is_integer(value) -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_live_period(params) do
    case Map.get(params, :live_period) do
      nil -> :ok
      period when is_integer(period) and period >= 60 and period <= 86_400 -> :ok
      _ -> {:error, "Invalid live_period: must be between 60 and 86_400 seconds"}
    end
  end
end
