defmodule Lux.Prisms.Web3.Events.ManageSubscription do
  @moduledoc """
  Prism for managing smart contract event subscriptions.
  """

  use Lux.Prism,
    name: "Event Subscription Manager",
    description: "Subscribe to, list, and unsubscribe from smart contract events",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["subscribe", "unsubscribe", "list", "history"]},
        contract_address: %{type: :string},
        chain: %{type: :string},
        event_types: %{type: :array},
        topics: %{type: :array},
        webhook_url: %{type: :string},
        subscription_id: %{type: :integer}
      },
      required: ["action"]
    },
    output_schema: %{type: :object}

  alias Lux.Integrations.Web3.Events.SubscriptionManager

  @impl true
  def handler(params, _opts) do
    action = params[:action] || params["action"]
    pid = params[:pid] || SubscriptionManager

    case action do
      "subscribe" ->
        case SubscriptionManager.subscribe(pid, params) do
          {:ok, sub} -> {:ok, %{subscription: sub, message: "Subscribed successfully"}}
          error -> error
        end

      "unsubscribe" ->
        sub_id = params[:subscription_id] || params["subscription_id"]
        case SubscriptionManager.unsubscribe(pid, sub_id) do
          :ok -> {:ok, %{message: "Unsubscribed successfully"}}
          error -> error
        end

      "list" ->
        subs = SubscriptionManager.list(pid)
        {:ok, %{subscriptions: subs, count: length(subs)}}

      "history" ->
        # Return stored events (would need EventMonitor integration)
        {:ok, %{events: [], message: "Use EventMonitor.get_events/2 for event history"}}

      _ ->
        {:error, "Unknown action: #{action}"}
    end
  end
end
