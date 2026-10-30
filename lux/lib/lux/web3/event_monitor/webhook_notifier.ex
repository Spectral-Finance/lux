defmodule Lux.Web3.EventMonitor.WebhookNotifier do
  @moduledoc """
  Dispatches structured contract events to external webhooks with exponential backoff retries.
  """
  require Logger

  @default_max_retries 3
  @default_timeout 5_000

  def dispatch(webhook_url, event, opts \\ []) do
    max_retries = Keyword.get(opts, :max_retries, @default_max_retries)
    payload = %{
      event: event[:event_name] || "ContractEvent",
      contract: event[:address],
      block_number: event[:block_number],
      transaction_hash: event[:transaction_hash],
      data: event[:data],
      topics: event[:topics] || [],
      timestamp: System.system_time(:second)
    }

    send_with_retry(webhook_url, payload, 1, max_retries)
  end

  defp send_with_retry(url, payload, attempt, max_retries) do
    case Req.post(url, json: payload, receive_timeout: @default_timeout) do
      {:ok, %{status: status}} when status in 200..299 ->
        Logger.debug("[WebhookNotifier] Successfully dispatched event to #{url}")
        :ok

      {:ok, %{status: status}} ->
        Logger.warning("[WebhookNotifier] Webhook returned status #{status}. Attempt #{attempt}/#{max_retries}")
        retry_or_fail(url, payload, attempt, max_retries)

      {:error, reason} ->
        Logger.warning("[WebhookNotifier] Failed to reach #{url}: #{inspect(reason)}. Attempt #{attempt}/#{max_retries}")
        retry_or_fail(url, payload, attempt, max_retries)
    end
  end

  defp retry_or_fail(_url, _payload, attempt, max_retries) when attempt >= max_retries do
    {:error, :max_retries_exceeded}
  end

  defp retry_or_fail(url, payload, attempt, max_retries) do
    backoff_ms = round(:math.pow(2, attempt) * 200)
    Process.sleep(backoff_ms)
    send_with_retry(url, payload, attempt + 1, max_retries)
  end
end
