defmodule Lux.Prisms.EventMonitor.RegisterWebhookPrism do
  @moduledoc """
  Prism for registering a webhook to receive smart contract event notifications.

  Webhooks provide a push-based mechanism for receiving event notifications
  at a specified URL whenever matching events are detected.

  ## Examples

      iex> Lux.Prisms.EventMonitor.RegisterWebhookPrism.run(%{
      ...>   url: "https://api.example.com/events",
      ...>   filter: %{event_name: "Transfer"},
      ...>   headers: %{"Authorization" => "Bearer token123"},
      ...>   secret: "webhook_secret_key"
      ...> })
      {:ok, %{webhook_id: "wh_abc123", status: "active"}}
  """

  use Lux.Prism,
    name: "Register Event Webhook",
    description: "Registers a webhook URL to receive smart contract event notifications",
    input_schema: %{
      type: :object,
      properties: %{
        url: %{
          type: :string,
          description: "Webhook URL to receive POST notifications"
        },
        filter: %{
          type: :object,
          description: "Event filter criteria (event_name, address, chain_id, etc.)"
        },
        headers: %{
          type: :object,
          description: "Additional HTTP headers to include in webhook requests"
        },
        secret: %{
          type: :string,
          description: "Shared secret for HMAC webhook signature verification"
        },
        max_retries: %{
          type: :integer,
          description: "Maximum retry attempts on failure (default: 3)"
        },
        retry_delay_ms: %{
          type: :integer,
          description: "Base delay between retries in ms (default: 1000)"
        }
      },
      required: ["url"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        webhook_id: %{
          type: :string,
          description: "Unique webhook identifier"
        },
        status: %{
          type: :string,
          description: "Webhook status"
        },
        url: %{
          type: :string,
          description: "Registered webhook URL"
        }
      },
      required: ["webhook_id", "status"]
    }

  alias Lux.EventMonitor

  @impl true
  def handler(input, ctx) do
    monitor = get_monitor(ctx)

    config = %{
      url: input[:url] || input["url"],
      filter: atomize_filter(input[:filter] || input["filter"] || %{}),
      headers: input[:headers] || input["headers"] || %{},
      secret: input[:secret] || input["secret"],
      max_retries: input[:max_retries] || input["max_retries"] || 3,
      retry_delay_ms: input[:retry_delay_ms] || input["retry_delay_ms"] || 1_000,
      active: true
    }

    case EventMonitor.register_webhook(monitor, config) do
      {:ok, webhook_id} ->
        {:ok, %{
          webhook_id: webhook_id,
          status: "active",
          url: config.url
        }}

      {:error, reason} ->
        {:error, "Failed to register webhook: #{inspect(reason)}"}
    end
  end

  defp get_monitor(nil), do: Lux.EventMonitor
  defp get_monitor(%{monitor: monitor}), do: monitor
  defp get_monitor(_), do: Lux.EventMonitor

  defp atomize_filter(filter) when is_map(filter) do
    Map.new(filter, fn
      {"event_name", v} -> {:event_name, v}
      {"address", v} -> {:address, v}
      {"chain_id", v} -> {:chain_id, v}
      {"from_block", v} -> {:from_block, v}
      {"to_block", v} -> {:to_block, v}
      {k, v} when is_atom(k) -> {k, v}
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
    end)
  end

  defp atomize_filter(filter), do: filter
end
