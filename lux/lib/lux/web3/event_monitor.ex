defmodule Lux.Web3.EventMonitor do
  @moduledoc """
  Core smart-contract event monitoring primitives.

  This module wires together subscriptions, log normalization, filtering,
  persistence, replay, and webhook notification. It intentionally stays
  transport-neutral, so live RPC and WebSocket adapters can call the same
  functions used by the tests.
  """

  alias Lux.Web3.EventMonitor.{Event, Matcher, Store, Subscription, SyncPlan, WebhookNotifier}

  @spec subscription(map() | keyword()) :: {:ok, Subscription.t()} | {:error, String.t()}
  defdelegate subscription(attrs), to: Subscription, as: :new

  @spec historical_ranges(Subscription.t(), non_neg_integer(), pos_integer()) :: [SyncPlan.range()]
  defdelegate historical_ranges(subscription, latest_block, batch_size \\ 2_000), to: SyncPlan, as: :ranges

  @doc """
  Normalizes a raw RPC log, checks it against subscriptions, stores matching
  events, and optionally delivers webhook notifications.
  """
  @spec ingest_log(map(), [Subscription.t()], keyword()) :: {:ok, [Event.t()]} | {:error, String.t()}
  def ingest_log(log, subscriptions, opts) when is_list(subscriptions) do
    with {:ok, chain_id} <- Keyword.fetch(opts, :chain_id),
         {:ok, event} <- Event.from_log(log, chain_id: chain_id, metadata: Keyword.get(opts, :metadata, %{})) do
      matches = Matcher.matching_subscriptions(subscriptions, event)
      events = Enum.map(matches, &assign_subscription(event, &1))

      if store = Keyword.get(opts, :store) do
        Store.put_many(store, events)
      end

      Enum.each(events, &maybe_notify(&1, matches, opts))

      {:ok, events}
    else
      :error -> {:error, "chain_id option is required"}
      error -> error
    end
  end

  defp assign_subscription(%Event{} = event, %Subscription{} = subscription) do
    %Event{event | subscription_id: subscription.id}
  end

  defp maybe_notify(%Event{} = event, subscriptions, opts) do
    subscription = Enum.find(subscriptions, &(&1.id == event.subscription_id))

    if subscription && subscription.webhook_url do
      WebhookNotifier.notify(event, subscription.webhook_url,
        secret: Keyword.get(opts, :webhook_secret),
        request_fun: Keyword.get(opts, :request_fun, &noop_request/3)
      )
    end
  end

  defp noop_request(_url, _body, _opts), do: {:ok, :not_configured}
end
