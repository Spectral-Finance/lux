defmodule Lux.Prisms.Discord.MessageManagementPrism do
  @moduledoc """
  A prism for managing Discord messages.
  Supports creating, editing, deleting, bulk deleting messages, and fetching message history.
  """
  use Lux.Prism,
    name: "Discord Message Management",
    description: "Handles Discord message operations including create, edit, delete, bulk delete, and history.",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["create", "edit", "delete", "bulk_delete", "history"],
          description: "The action to perform."
        },
        channel_id: %{
          type: :string,
          description: "The channel ID."
        },
        message_id: %{
          type: :string,
          description: "The message ID (for edit/delete)."
        },
        content: %{
          type: :string,
          description: "The message content (for create/edit)."
        },
        message_ids: %{
          type: :array,
          items: %{type: :string},
          description: "List of message IDs (for bulk_delete)."
        },
        limit: %{
          type: :integer,
          description: "Number of messages to fetch (for history)."
        }
      },
      required: ["action", "channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{
          type: :string,
          description: "Status of the operation."
        },
        data: %{
          type: :object,
          description: "Resulting data (e.g. message object or list of messages)."
        }
      },
      required: ["status"]
    }

  alias Lux.Integrations.Discord.Client

  def handler(params, _ctx) do
    with {:ok, action} <- fetch_param(params, :action),
         {:ok, channel_id} <- fetch_param(params, :channel_id) do

    case action do
      "create" -> create_message(channel_id, params)
      "edit" -> edit_message(channel_id, params)
      "delete" -> delete_message(channel_id, params)
      "bulk_delete" -> bulk_delete_messages(channel_id, params)
      "history" -> fetch_history(channel_id, params)
      _ -> {:error, "Invalid action"}
    end
  end
  end

  defp create_message(channel_id, params) do
    case fetch_param(params, :content) do
      {:ok, content} ->
        with_retry(fn ->
          Client.request(:post, "/channels/#{channel_id}/messages", %{json: %{content: content}})
        end)
        |> format_response()

      :error ->
        {:error, "content is required for create action"}
    end
  end

  defp edit_message(channel_id, params) do
    with {:ok, message_id} <- fetch_param(params, :message_id),
         {:ok, content} <- fetch_param(params, :content) do
      with_retry(fn ->
        Client.request(:patch, "/channels/#{channel_id}/messages/#{message_id}", %{
          json: %{content: content}
        })
      end)
      |> format_response()
    else
      _ -> {:error, "message_id and content are required for edit action"}
    end
  end

  defp delete_message(channel_id, params) do
    case fetch_param(params, :message_id) do
      {:ok, message_id} ->
        with_retry(fn ->
          Client.request(:delete, "/channels/#{channel_id}/messages/#{message_id}")
        end)
        |> format_response(%{})

      :error ->
        {:error, "message_id is required for delete action"}
    end
  end

  defp bulk_delete_messages(channel_id, params) do
    case fetch_param(params, :message_ids) do
      {:ok, message_ids} when is_list(message_ids) ->
        with_retry(fn ->
          Client.request(:post, "/channels/#{channel_id}/messages/bulk-delete", %{
            json: %{messages: message_ids}
          })
        end)
        |> format_response(%{})

      _ ->
        {:error, "message_ids array is required for bulk_delete action"}
    end
  end

  defp fetch_history(channel_id, params) do
    limit = get_param(params, :limit, 50)

    with_retry(fn ->
      Client.request(:get, "/channels/#{channel_id}/messages?limit=#{limit}")
    end)
    |> format_response()
  end

  defp format_response({:ok, body}) do
    body = if body == "", do: %{}, else: body
    # Discord might return lists (e.g. for history)
    body = if is_list(body), do: %{messages: body}, else: body
    {:ok, %{status: "success", data: body}}
  end

  defp format_response({:error, reason}), do: {:error, reason}
  defp format_response({:ok, _body}, default), do: {:ok, %{status: "success", data: default}}

  # Simple retry mechanism for 429 Too Many Requests
  defp with_retry(func, retries \\ 3) do
    case func.() do
      {:error, {429, msg}} when retries > 0 ->
        unless Application.get_env(:lux, :env) == :test do
          delay =
            case msg do
              %{"retry_after" => r} when is_number(r) -> trunc(r * 1000)
              _ -> 100
            end
          Process.sleep(delay)
        end
        with_retry(func, retries - 1)

      other ->
        other
    end
  end

  defp normalize_keys(params) do
    Map.new(params, fn
      {k, v} when is_binary(k) ->
        case safe_to_existing_atom(k) do
          nil -> {k, v}
          atom -> {atom, v}
        end
      {k, v} -> {k, v}
    end)
  end

  defp safe_to_existing_atom(key) do
    try do
      String.to_existing_atom(key)
    rescue
      ArgumentError -> nil
    end
  end

  defp fetch_param(params, key) do
    string_key = Atom.to_string(key)

    cond do
      Map.has_key?(params, key) -> {:ok, Map.fetch!(params, key)}
      Map.has_key?(params, string_key) -> {:ok, Map.fetch!(params, string_key)}
      true -> {:error, "#{string_key} is required"}
    end
  end

  defp get_param(params, key, default \\ nil) do
    case fetch_param(params, key) do
      {:ok, value} -> value
      {:error, _} -> default
    end
  end
end
