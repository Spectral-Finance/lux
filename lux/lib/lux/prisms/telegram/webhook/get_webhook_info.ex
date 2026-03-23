defmodule Lux.Prisms.Telegram.Webhook.GetWebhookInfo do
  @moduledoc """
  A prism for getting current webhook status via the Telegram Bot API.

  This prism provides an interface to call the getWebhookInfo endpoint, which
  returns the current status of the webhook including URL, pending update count,
  and any errors.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /getWebhookInfo
  - No required parameters
  - Returns WebhookInfo object with url, has_custom_certificate, pending_update_count, etc.

  ## Examples

      iex> GetWebhookInfo.handler(%{}, %{name: "Agent"})
      {:ok, %{url: "https://example.com/webhook", has_custom_certificate: false, pending_update_count: 0}}
  """

  use Lux.Prism,
    name: "Get Telegram Webhook Info",
    description: "Returns current webhook status via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{},
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        url: %{
          type: :string,
          description: "Webhook URL, may be empty if webhook is not set up"
        },
        has_custom_certificate: %{
          type: :boolean,
          description: "True, if a custom certificate was provided for webhook certificate checks"
        },
        pending_update_count: %{
          type: :integer,
          description: "Number of updates awaiting delivery"
        },
        ip_address: %{
          type: :string,
          description: "Currently used webhook IP address"
        },
        last_error_date: %{
          type: :integer,
          description: "Unix time for the most recent error that happened when trying to deliver an update"
        },
        last_error_message: %{
          type: :string,
          description: "Error message in human-readable format for the most recent error"
        },
        last_synchronization_error_date: %{
          type: :integer,
          description: "Unix time of the most recent error that happened when trying to synchronize available updates"
        },
        max_connections: %{
          type: :integer,
          description: "The maximum allowed number of simultaneous HTTPS connections to the webhook"
        },
        allowed_updates: %{
          type: :array,
          description: "A list of update types the bot is subscribed to"
        }
      },
      required: ["url", "has_custom_certificate", "pending_update_count"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to get webhook info.
  """
  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} getting webhook info")

    request_opts = %{json: %{}}
    request_opts = maybe_add_plug(request_opts, params[:plug])

    case Client.request(:post, "/getWebhookInfo", request_opts) do
      {:ok, %{"result" => result}} ->
        Logger.info("Successfully retrieved webhook info")
        {:ok, %{
          url: result["url"],
          has_custom_certificate: result["has_custom_certificate"],
          pending_update_count: result["pending_update_count"],
          ip_address: result["ip_address"],
          last_error_date: result["last_error_date"],
          last_error_message: result["last_error_message"],
          last_synchronization_error_date: result["last_synchronization_error_date"],
          max_connections: result["max_connections"],
          allowed_updates: result["allowed_updates"]
        }}

      {:error, {status, description}} when is_binary(description) ->
        {:error, "Failed to get webhook info: #{description} (HTTP #{status})"}

      {:error, error} ->
        {:error, "Failed to get webhook info: #{inspect(error)}"}
    end
  end

  defp maybe_add_plug(opts, nil), do: opts
  defp maybe_add_plug(opts, plug), do: Map.put(opts, :plug, plug)
end
