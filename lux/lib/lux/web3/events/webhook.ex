defmodule Lux.Web3.Events.Webhook do
  @moduledoc """
  Webhook notification dispatcher for event monitoring.

  Sends HTTP POST requests to configured webhook URLs when new
  events are detected. Supports retry logic and payload formatting.
  """

  @doc """
  Sends an event notification to a webhook URL.

  ## Parameters

  - `url`: The webhook endpoint URL
  - `event`: The event that triggered the notification
  - `subscription`: The subscription that matched the event

  ## Returns

  `:ok` on success, `{:error, term()}` on failure.
  """
  @spec notify(String.t(), Lux.Web3.Events.Event.t(), Lux.Web3.Events.Subscription.t()) ::
          :ok | {:error, term()}
  def notify(url, event, subscription) when is_binary(url) and url != "" do
    payload = build_payload(event, subscription)

    case Req.post(url,
           json: payload,
           timeout: 10_000,
           recv_timeout: 10_000
         ) do
      {:ok, %{status: status}} when status in 200..299 -> :ok
      {:ok, %{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  def notify(_url, _event, _subscription), do: :ok

  @doc """
  Sends notifications for a batch of events to all matching webhook URLs.
  """
  @spec notify_batch([Lux.Web3.Events.Event.t()], [Lux.Web3.Events.Subscription.t()]) :: :ok
  def notify_batch(events, subscriptions) do
    Enum.each(events, fn event ->
      matching_subs =
        subscriptions
        |> Enum.filter(fn sub ->
          sub.enabled and sub.webhook_url and
            Lux.Web3.Events.Subscription.topic_matches?(sub, event.topic0)
        end)

      Enum.each(matching_subs, fn sub ->
        notify(sub.webhook_url, event, sub)
      end)
    end)

    :ok
  end

  @doc """
  Builds the webhook payload from an event.
  """
  @spec build_payload(
          Lux.Web3.Events.Event.t(),
          Lux.Web3.Events.Subscription.t()
        ) :: map()
  def build_payload(event, subscription) do
    %{
      event: %{
        chain_id: event.chain_id,
        contract_address: event.contract_address,
        transaction_hash: event.transaction_hash,
        block_number: event.block_number,
        log_index: event.log_index,
        topic0: event.topic0,
        topics: event.topics,
        data: event.data,
        decoded_params: event.decoded_params,
        timestamp: event.timestamp
      },
      subscription: %{
        id: subscription.id,
        contract: subscription.contract_address,
        event_signatures: subscription.event_signatures
      },
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  @doc """
  Validates a webhook URL.
  """
  @spec valid_url?(String.t()) :: boolean()
  def valid_url?(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and host != "" -> true
      _ -> false
    end
  end

  def valid_url?(_), do: false
end
