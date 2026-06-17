defmodule Lux.Prisms.Telegram.Messaging.SetWebhook do
  @moduledoc """
  A prism for setting a webhook for Telegram updates.
  """

  use Lux.Prism,
    name: "Set Telegram Webhook",
    description: "Sets a webhook for receiving Telegram updates",
    input_schema: %{
      type: :object,
      properties: %{
        url: %{type: :string, description: "HTTPS URL to send updates to"},
        certificate: %{type: :string, description: "Public key certificate"},
        ip_address: %{type: :string, description: "The fixed IP address"},
        max_connections: %{type: :integer, description: "Maximum number of connections (1-100)", default: 40},
        allowed_updates: %{
          type: :array,
          description: "List of update types to receive",
          items: %{type: :string}
        },
        drop_pending_updates: %{type: :boolean, description: "Drop all pending updates"}
      },
      required: ["url"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        set: %{type: :boolean, description: "Whether the webhook was set"},
        url: %{type: :string, description: "The webhook URL"}
      },
      required: ["set"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, url} <- validate_param(params, :url) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} setting webhook to #{url}")

      json = %{url: url}
      json = maybe_add_optional(json, params, :certificate)
      json = maybe_add_optional(json, params, :ip_address)
      json = maybe_add_optional(json, params, :max_connections)
      json = maybe_add_optional(json, params, :allowed_updates)
      json = maybe_add_optional(json, params, :drop_pending_updates)

      case Client.request(:post, "/setWebhook", %{json: json}) do
        {:ok, _result} ->
          Logger.info("Successfully set webhook to #{url}")
          {:ok, %{set: true, url: url}}

        {:error, {status, description}} ->
          Logger.error("Failed to set webhook: {#{status}, #{description}}")
          {:error, {status, description}}

        {:error, error} ->
          Logger.error("Failed to set webhook: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      {:ok, value} when is_boolean(value) -> {:ok, value}
      {:ok, value} when is_integer(value) -> {:ok, value}
      {:ok, value} when is_list(value) -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp maybe_add_optional(json, params, key) do
    case Map.fetch(params, key) do
      {:ok, value} -> Map.put(json, key, value)
      :error -> json
    end
  end
end
