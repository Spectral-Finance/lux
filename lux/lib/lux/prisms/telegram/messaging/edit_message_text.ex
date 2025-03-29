defmodule Lux.Prisms.Telegram.Messages.EditMessageText do
  @moduledoc """
  A prism for editing message text via the Telegram Bot API.

  This prism provides a simple interface to edit text messages in Telegram chats.
  It uses the Telegram Bot API to edit the text of existing messages that the bot has permission to modify.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /editMessageText
  - Supports required parameters (chat_id & message_id or inline_message_id, and text)
  - Returns the modified message on successful editing for chat messages
  - Returns true on successful editing for inline messages
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      # Edit a message text
      iex> EditMessageText.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   message_id: 42,
      ...>   text: "Updated message text"
      ...> }, %{name: "Agent"})
      {:ok, %{edited: true, message_id: 42, chat_id: 123_456_789, text: "Updated message text"}}

      # Edit a message with markdown formatting
      iex> EditMessageText.handler(%{
      ...>   chat_id: 123_456_789,
      ...>   message_id: 42,
      ...>   text: "*Bold* and _italic_ text",
      ...>   parse_mode: "Markdown"
      ...> }, %{name: "Agent"})
      {:ok, %{edited: true, message_id: 42, chat_id: 123_456_789, text: "*Bold* and _italic_ text"}}

      # Edit an inline message text
      iex> EditMessageText.handler(%{
      ...>   inline_message_id: "123_456_789",
      ...>   text: "Updated inline message text"
      ...> }, %{name: "Agent"})
      {:ok, %{edited: true}}
  """

  use Lux.Prism,
    name: "Edit Telegram Message Text",
    description: "Edits the text of a message in a Telegram chat",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Required if inline_message_id is not specified. Unique identifier for the target chat or username of the target channel"
        },
        message_id: %{
          type: :integer,
          description: "Required if inline_message_id is not specified. Identifier of the message to edit"
        },
        inline_message_id: %{
          type: :string,
          description: "Required if chat_id and message_id are not specified. Identifier of the inline message"
        },
        text: %{
          type: :string,
          description: "New text of the message, 1-4096 characters after entities parsing"
        },
        parse_mode: %{
          type: :string,
          description: "Mode for parsing entities in the message text",
          enum: ["Markdown", "MarkdownV2", "HTML"]
        },
        entities: %{
          type: :array,
          description: "A JSON-serialized list of special entities that appear in message text"
        },
        disable_web_page_preview: %{
          type: :boolean,
          description: "Disables link previews for links in this message"
        },
        reply_markup: %{
          type: :object,
          description: "A JSON-serialized object for an inline keyboard"
        }
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        edited: %{
          type: :boolean,
          description: "Whether the message text was successfully edited"
        },
        message_id: %{
          type: [:string, :integer],
          description: "The ID of the edited message (for chat messages)"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "The chat ID where the message was edited (for chat messages)"
        },
        text: %{
          type: :string,
          description: "The new text of the message"
        }
      },
      required: ["edited"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to edit a message text in a Telegram chat.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns success/failure responses without additional error transformation
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    cond do
      Map.has_key?(params, :inline_message_id) ->
        handle_inline_message(params, agent)
      
      Map.has_key?(params, :chat_id) && Map.has_key?(params, :message_id) ->
        handle_chat_message(params, agent)
      
      true ->
        {:error, "Missing required parameters: either (chat_id and message_id) or inline_message_id must be provided"}
    end
  end

  defp handle_chat_message(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, message_id} <- validate_param(params, :message_id, :integer),
         {:ok, text} <- validate_param(params, :text) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} editing text of message #{message_id} in chat #{chat_id}")

      # Build the request body with all permitted parameters
      request_body = params
                     |> Map.take([:chat_id, :message_id, :text, :parse_mode, 
                                  :entities, :disable_web_page_preview, :reply_markup])
                     |> transform_param_types()

      # Prepare request options
      request_opts = %{json: request_body}
      
      # Add plug option for testing if provided
      request_opts = if Map.has_key?(params, :plug) do
        Map.put(request_opts, :plug, params.plug)
      else
        request_opts
      end

      case Client.request(:post, "/editMessageText", request_opts) do
        {:ok, %{"result" => result}} when is_map(result) ->
          Logger.info("Successfully edited text of message #{message_id} in chat #{chat_id}")
          {:ok, %{
            edited: true, 
            message_id: message_id, 
            chat_id: chat_id,
            text: text
          }}
        
        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to edit message text: #{description} (HTTP #{status})"}
          
        {:error, error} ->
          {:error, "Failed to edit message text: #{inspect(error)}"}
      end
    end
  end

  defp handle_inline_message(params, agent) do
    with {:ok, inline_message_id} <- validate_param(params, :inline_message_id),
         {:ok, _text} <- validate_param(params, :text) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} editing text of inline message #{inline_message_id}")

      # Build the request body with all permitted parameters
      request_body = params
                     |> Map.take([:inline_message_id, :text, :parse_mode, 
                                  :entities, :disable_web_page_preview, :reply_markup])
                     |> transform_param_types()

      # Prepare request options
      request_opts = %{json: request_body}
      
      # Add plug option for testing if provided
      request_opts = if Map.has_key?(params, :plug) do
        Map.put(request_opts, :plug, params.plug)
      else
        request_opts
      end

      case Client.request(:post, "/editMessageText", request_opts) do
        {:ok, %{"result" => true}} ->
          Logger.info("Successfully edited text of inline message #{inline_message_id}")
          {:ok, %{edited: true}}
        
        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to edit inline message text: #{description} (HTTP #{status})"}
          
        {:error, error} ->
          {:error, "Failed to edit inline message text: #{inspect(error)}"}
      end
    end
  end

  defp validate_param(params, key, _type \\ :any) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      {:ok, value} when is_integer(value) -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  # Transform parameters to the correct types expected by the Telegram API
  defp transform_param_types(params) do
    params
    |> Enum.reduce(%{}, fn
      # Skip "schema" and other non-desired attributes
      {key, _value}, acc when key in ["schema", "lux"] ->
        acc
      {key, value}, _acc when is_binary(value) and key in [:chat_id] -> 
        # Try to convert string chat_id to integer if it's numeric
        case Integer.parse(value) do
          {int_value, ""} -> {stringify_key(key), int_value}
          _ -> {stringify_key(key), value}
        end
      # Handle nested maps recursively
      {key, value}, acc when is_map(value) ->
        Map.put(acc, stringify_key(key), transform_param_types(value))
      # Handle lists that might contain maps
      {key, value}, acc when is_list(value) ->
        Map.put(acc, stringify_key(key), Enum.map(value, &transform_list_item/1))
      # Convert any other pairs ensuring the key is a string
      {key, value}, acc -> Map.put(acc, stringify_key(key), value)
    end)
  end

  # Helper function to stringify keys
  defp stringify_key(key) when is_atom(key), do: Atom.to_string(key)
  defp stringify_key(key) when is_binary(key), do: key
  defp stringify_key(key), do: "#{key}"

  # Handle non-list items
  defp transform_list_item(item) do
    if is_map(item), do: transform_param_types(item), else: item
  end
end 