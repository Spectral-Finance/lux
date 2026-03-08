defmodule Lux.Prisms.Telegram.ManageWebhook do
  @moduledoc """
  Prism for managing Telegram webhook configuration.
  """

  use Lux.Prism,
    name: "Telegram Manage Webhook",
    description: "Set, delete, or get webhook info",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["set", "delete", "info"]},
        url: %{type: :string, description: "Webhook URL (for set)"},
        secret_token: %{type: :string, description: "Secret token for verification"},
        max_connections: %{type: :integer},
        allowed_updates: %{type: :array},
        token: %{type: :string}
      },
      required: ["action", "token"]
    },
    output_schema: %{type: :object}

  alias Lux.Integrations.Telegram.Client

  @impl true
  def handler(params, _opts) do
    action = params[:action] || params["action"]

    case action do
      "set" -> set_webhook(params)
      "delete" -> delete_webhook(params)
      "info" -> get_webhook_info(params)
      _ -> {:error, "Unknown action: #{action}"}
    end
  end

  defp set_webhook(params) do
    api_params =
      %{url: params[:url] || params["url"]}
      |> maybe_put(:secret_token, params[:secret_token] || params["secret_token"])
      |> maybe_put(:max_connections, params[:max_connections] || params["max_connections"])
      |> maybe_put(:allowed_updates, params[:allowed_updates] || params["allowed_updates"])

    Client.request("setWebhook", api_params, build_opts(params))
  end

  defp delete_webhook(params) do
    Client.request("deleteWebhook", %{}, build_opts(params))
  end

  defp get_webhook_info(params) do
    Client.request("getWebhookInfo", %{}, build_opts(params))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp build_opts(params) do
    opts = [token: params[:token] || params["token"]]
    if params[:plug], do: Keyword.put(opts, :plug, params[:plug]), else: opts
  end
end
