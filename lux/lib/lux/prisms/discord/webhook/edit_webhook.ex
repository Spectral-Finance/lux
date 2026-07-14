defmodule Lux.Prisms.Discord.Webhook.EditWebhook do
  @moduledoc """
  Edit an existing webhook in a Discord channel.

  This prism allows updating the webhook's name, avatar, or both.

  Requires the \"Manage Webhooks\" permission.

  ## Examples

      iex> EditWebhook.handler(%{
      ...>   webhook_id: \"123456789\",
      ...>   name: \"Updated Bot\"
      ...> }, %{name: \"Agent\"})
      {:ok, %{
        webhook_id: \"123456789\",
        name: \"Updated Bot\"
      }}
  """

  use Lux.Prism,
    name: "Edit Discord Webhook",
    description: "Edits an existing webhook's properties",
    input_schema: %{
      type: :object,
      properties: %{
        webhook_id: %{
          type: :string,
          description: "The ID of the webhook to edit",
          pattern: "^[0-9]{17,20}$"
        },
        name: %{
          type: :string,
          description: "New name for the webhook (1-80 characters)",
          minLength: 1,
          maxLength: 80
        },
        avatar_url: %{
          type: :string,
          description: "New avatar URL for the webhook (PNG/JPEG/WebP)"
        }
      },
      required: ["webhook_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        webhook_id: %{
          type: :string,
          description: "The ID of the edited webhook"
        },
        name: %{
          type: :string,
          description: "The updated name"
        },
        channel_id: %{
          type: :string,
          description: "The channel where the webhook belongs"
        },
        avatar_url: %{
          type: :string,
          description: "The avatar URL if updated"
        }
      },
      required: ["webhook_id"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Edits an existing webhook.

  At least one of :name or :avatar_url must be provided.
  """
  @spec handler(map(), map()) :: {:ok, map()} | {:error, any()}
  def handler(params, agent) do
    with {:ok, webhook_id} <- validate_webhook_id(params),
         {:ok, changes} <- build_edit_body(params) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} editing webhook #{webhook_id}: #{inspect(changes)}")

      case Client.request(:patch, "/webhooks/#{webhook_id}", %{json: changes}) do
        {:ok, %{"id" => returned_id, "name" => name, "channel_id" => channel_id} = resp} ->
          Logger.info("Successfully edited webhook #{returned_id}")

          {:ok,
           %{
             webhook_id: returned_id,
             name: name,
             channel_id: channel_id,
             avatar_url: resp["avatar"]
           }}

        {:error, {status, message}} ->
          Logger.error("Failed to edit webhook #{webhook_id}: #{inspect({status, message})}")
          {:error, {status, message}}

        {:error, error} ->
          Logger.error("Failed to edit webhook #{webhook_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp validate_webhook_id(params) do
    case Map.fetch(params, :webhook_id) do
      {:ok, val} when is_binary(val) and byte_size(val) > 0 -> {:ok, val}
      _ -> {:error, "Missing or invalid webhook_id"}
    end
  end

  defp build_edit_body(params) do
    name = Map.get(params, :name)
    avatar = Map.get(params, :avatar_url)

    cond do
      is_nil(name) and is_nil(avatar) ->
        {:error, "At least one of :name or :avatar_url must be provided"}

      true ->
        body = %{}
        body = if(name, do: Map.put(body, "name", name), else: body)
        body = if(avatar, do: Map.put(body, "avatar", avatar), else: body)
        {:ok, body}
    end
  end
end
