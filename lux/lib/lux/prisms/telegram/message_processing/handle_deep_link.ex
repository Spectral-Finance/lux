defmodule Lux.Prisms.Telegram.MessageProcessing.HandleDeepLink do
  @moduledoc """
  A prism for decoding incoming deep link payloads and generating outgoing deep link URLs.
  """

  use Lux.Prism,
    name: "Handle Telegram Deep Link",
    description: "Decodes Telegram start payloads and generates compliant deep link URLs",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, description: "'parse' or 'generate'"},
        payload: %{type: [:string, :object], description: "Payload to decode or encode"},
        bot_username: %{type: :string, description: "Bot username for generating links"},
        link_type: %{type: :string, description: "'bot', 'group', or 'mini_app'"},
        app_name: %{type: :string, description: "Mini-app name if type is 'mini_app'"}
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        data: %{type: :object},
        url: %{type: :string}
      },
      required: ["status"]
    }

  alias Lux.Integrations.Telegram.MessageProcessing.DeepLinkHandler

  def handler(params, _agent) when is_map(params) do
    action = Map.get(params, :action) || Map.get(params, "action", "parse")

    case to_string(action) do
      "parse" ->
        payload = Map.get(params, :payload) || Map.get(params, "payload") || ""

        case DeepLinkHandler.parse(payload) do
          {:ok, data} ->
            {:ok, %{status: "ok", data: data}}

          {:error, reason} ->
            {:error, reason}
        end

      "generate" ->
        bot_username = Map.get(params, :bot_username) || Map.get(params, "bot_username", "MyBot")
        payload = Map.get(params, :payload) || Map.get(params, "payload") || ""
        link_type = String.to_atom(to_string(Map.get(params, :link_type) || Map.get(params, "link_type", "bot")))
        app_name = Map.get(params, :app_name) || Map.get(params, "app_name")

        opts = [type: link_type]
        opts = if app_name, do: [{:app_name, app_name} | opts], else: opts

        case DeepLinkHandler.generate_link(bot_username, payload, opts) do
          {:ok, url} ->
            {:ok, %{status: "ok", url: url}}

          {:error, reason} ->
            {:error, reason}
        end

      other ->
        {:error, "Unsupported action: #{other}"}
    end
  end

  def handler(_, _), do: {:error, "Invalid input"}
end
