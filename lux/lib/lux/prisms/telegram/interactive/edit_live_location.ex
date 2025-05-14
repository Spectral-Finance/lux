defmodule Lux.Prisms.Telegram.Interactive.EditLiveLocation do
  @moduledoc """
  A prism for editing live location messages via the Telegram Bot API.

  This prism provides a simple interface to update the location of previously sent live location messages.
  It uses the Telegram Bot API to edit the coordinates of an active live location.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /editMessageLiveLocation
  - Supports updating the location coordinates of a previously sent live location
  - Returns the updated message or success status on success
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Edit a live location in a chat
      iex> EditLiveLocation.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   message_id: 42,
      ...>   latitude: 37.7858,
      ...>   longitude: -122.4064
      ...> }, %{name: "Agent"})
      {:ok, %{updated: true, message_id: 42, chat_id: 123_456_789, latitude: 37.7858, longitude: -122.4064}}

      # Edit a live location for an inline message
      iex> EditLiveLocation.handler(%{
      ...>   inline_message_id: "CAAqrxJRAqABAZaiqJ4sAJtvlCQI",
      ...>   latitude: 37.7858,
      ...>   longitude: -122.4064
      ...> }, %{name: "Agent"})
      {:ok, %{updated: true, inline_message_id: "CAAqrxJRAqABAZaiqJ4sAJtvlCQI", latitude: 37.7858, longitude: -122.4064}}

      # Edit a live location with additional parameters
      iex> EditLiveLocation.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   message_id: 42,
      ...>   latitude: 37.7858,
      ...>   longitude: -122.4064,
      ...>   horizontal_accuracy: 65.4,
      ...>   heading: 90,
      ...>   proximity_alert_radius: 200
      ...> }, %{name: "Agent"})
      {:ok, %{updated: true, message_id: 42, chat_id: 123_456_789, latitude: 37.7858, longitude: -122.4064}}
  """

  use Lux.Prism,
    name: "Edit Telegram Live Location",
    description: "Updates the location in a live location message via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Required if inline_message_id is not specified. Unique identifier for the target chat or username of the target channel"
        },
        message_id: %{
          type: :integer,
          description: "Required if inline_message_id is not specified. Identifier of the message with live location to edit"
        },
        inline_message_id: %{
          type: :string,
          description: "Required if chat_id and message_id are not specified. Identifier of the inline message"
        },
        latitude: %{
          type: :number,
          description: "Latitude of the new location"
        },
        longitude: %{
          type: :number,
          description: "Longitude of the new location"
        },
        horizontal_accuracy: %{
          type: :number,
          description: "The radius of uncertainty for the location, measured in meters; 0-1500"
        },
        heading: %{
          type: :integer,
          description: "Direction in which the user is moving, in degrees. Must be between 1 and 360 if specified"
        },
        proximity_alert_radius: %{
          type: :integer,
          description: "Maximum distance for proximity alerts about approaching another chat member, in meters"
        },
        reply_markup: %{
          type: :object,
          description: "A JSON-serialized object for a new inline keyboard"
        }
      },
      required: ["latitude", "longitude"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        updated: %{
          type: :boolean,
          description: "Whether the live location was successfully updated"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the message with live location"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Identifier of the chat"
        },
        inline_message_id: %{
          type: :string,
          description: "Identifier of the inline message"
        },
        latitude: %{
          type: :number,
          description: "Latitude of the updated location"
        },
        longitude: %{
          type: :number,
          description: "Longitude of the updated location"
        }
      },
      required: ["updated"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to edit a live location message.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, latitude} <- validate_param(params, :latitude, :number),
         {:ok, longitude} <- validate_param(params, :longitude, :number),
         :ok <- validate_message_identifiers(params),
         :ok <- validate_optional_params(params) do

      agent_name = agent[:name] || "Unknown Agent"
      message_identifier = get_message_identifier(params)

      Logger.info("Agent #{agent_name} updating live location for #{message_identifier} to coordinates (#{latitude}, #{longitude})")

      # Build the request body
      request_body = Map.take(params, [:chat_id, :message_id, :inline_message_id, :latitude, :longitude,
                              :horizontal_accuracy, :heading, :proximity_alert_radius, :reply_markup])

      # Prepare request options
      request_opts = %{json: request_body}

      case Client.request(:post, "/editMessageLiveLocation", request_opts) do
        {:ok, %{"result" => result}} when is_map(result) ->
          handle_successful_response(message_identifier, params, latitude, longitude)

        {:ok, %{"result" => true}} ->
          # For inline messages, we might just get a success boolean
          handle_successful_boolean_response(message_identifier, params, latitude, longitude)

        {:error, error} ->
          handle_error_response(error)
      end
    end
  end

  defp handle_successful_response(message_identifier, params, latitude, longitude) do
    Logger.info("Successfully updated live location for #{message_identifier}")

    # Build base response
    response = %{
      updated: true,
      latitude: latitude,
      longitude: longitude
    }

    {:ok, add_message_identifier_to_response(response, params)}
  end

  defp handle_successful_boolean_response(message_identifier, params, latitude, longitude) do
    Logger.info("Successfully updated live location for #{message_identifier}")

    response = %{
      updated: true,
      latitude: latitude,
      longitude: longitude
    }

    # Add the inline_message_id if it exists
    response = if inline_id = Map.get(params, :inline_message_id) do
      Map.put(response, :inline_message_id, inline_id)
    else
      response
    end

    {:ok, response}
  end

  defp handle_error_response(error) do
    case error do
      {status, %{"description" => description}} ->
        {:error, "Failed to update live location: #{description} (HTTP #{status})"}

      {status, description} when is_binary(description) ->
        {:error, "Failed to update live location: #{description} (HTTP #{status})"}

      _ ->
        {:error, "Failed to update live location: #{inspect(error)}"}
    end
  end

  defp get_message_identifier(params) do
    case {Map.get(params, :chat_id), Map.get(params, :message_id), Map.get(params, :inline_message_id)} do
      {chat_id, message_id, nil} when not is_nil(chat_id) and not is_nil(message_id) ->
        "message_id: #{message_id} in chat: #{chat_id}"
      {nil, nil, inline_message_id} when not is_nil(inline_message_id) ->
        "inline_message: #{inline_message_id}"
      _ ->
        "unknown message"
    end
  end

  defp add_message_identifier_to_response(response, params) do
    case {Map.get(params, :chat_id), Map.get(params, :message_id), Map.get(params, :inline_message_id)} do
      {chat_id, message_id, nil} when not is_nil(chat_id) and not is_nil(message_id) ->
        response
        |> Map.put(:chat_id, chat_id)
        |> Map.put(:message_id, message_id)
      {nil, nil, inline_message_id} when not is_nil(inline_message_id) ->
        Map.put(response, :inline_message_id, inline_message_id)
      _ ->
        response
    end
  end

  defp validate_param(params, key, :number) do
    case Map.fetch(params, key) do
      {:ok, value} when is_number(value) -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_message_identifiers(params) do
    case {Map.get(params, :chat_id), Map.get(params, :message_id), Map.get(params, :inline_message_id)} do
      {chat_id, message_id, nil} when not is_nil(chat_id) and not is_nil(message_id) ->
        :ok
      {nil, nil, inline_message_id} when not is_nil(inline_message_id) ->
        :ok
      _ ->
        {:error, "Missing or invalid message identifier: Either (chat_id and message_id) or inline_message_id must be provided"}
    end
  end

  defp validate_optional_params(params) do
    case validate_horizontal_accuracy(params) do
      :ok ->
        case validate_heading(params) do
          :ok -> validate_proximity_radius(params)
          error -> error
        end
      error -> error
    end
  end

  defp validate_horizontal_accuracy(params) do
    horizontal_accuracy = Map.get(params, :horizontal_accuracy)

    if is_nil(horizontal_accuracy) do
      :ok
    else
      if is_number(horizontal_accuracy) and horizontal_accuracy >= 0 and horizontal_accuracy <= 1500 do
        :ok
      else
        {:error, "horizontal_accuracy must be between 0 and 1500"}
      end
    end
  end

  defp validate_heading(params) do
    heading = Map.get(params, :heading)

    if is_nil(heading) do
      :ok
    else
      if is_integer(heading) and heading >= 1 and heading <= 360 do
        :ok
      else
        {:error, "heading must be between 1 and 360"}
      end
    end
  end

  defp validate_proximity_radius(params) do
    proximity_radius = Map.get(params, :proximity_alert_radius)

    if is_nil(proximity_radius) do
      :ok
    else
      if is_integer(proximity_radius) and proximity_radius > 0 do
        :ok
      else
        {:error, "proximity_alert_radius must be a positive integer"}
      end
    end
  end
end
