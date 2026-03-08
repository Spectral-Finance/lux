defmodule Lux.Integrations.Web3.Events.WebhookNotifier do
  @moduledoc """
  Delivers event notifications to registered webhook URLs via HTTP POST.

  Supports retry with exponential backoff, payload signing for verification,
  and delivery status tracking.
  """

  require Logger

  @max_retries 3
  @base_delay_ms 1_000

  defstruct [:url, :secret, :events_delivered, :events_failed, :last_error]

  @doc "Send an event to a webhook URL with optional HMAC signing."
  def deliver(url, event, opts \\ []) do
    secret = opts[:secret]
    plug = opts[:plug]

    payload = Jason.encode!(%{
      event_type: event[:type] || event.type,
      address: event[:address] || event.address,
      block_number: event[:block_number] || event.block_number,
      transaction_hash: event[:transaction_hash] || event.transaction_hash,
      data: event,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })

    headers = [{"content-type", "application/json"}]
    headers = if secret do
      signature = :crypto.mac(:hmac, :sha256, secret, payload) |> Base.encode16(case: :lower)
      [{"x-webhook-signature", "sha256=#{signature}"} | headers]
    else
      headers
    end

    do_deliver(url, payload, headers, 0, plug)
  end

  @doc "Deliver events to all matching webhook subscribers."
  def deliver_to_subscribers(event, subscriptions, opts \\ []) do
    subscriptions
    |> Enum.filter(&(&1.webhook_url != nil))
    |> Enum.map(fn sub ->
      result = deliver(sub.webhook_url, event, opts)
      {sub.id, result}
    end)
  end

  @doc "Verify a webhook payload signature."
  def verify_signature(payload, signature, secret) do
    expected = :crypto.mac(:hmac, :sha256, secret, payload) |> Base.encode16(case: :lower)
    "sha256=#{expected}" == signature
  end

  defp do_deliver(_url, _payload, _headers, attempt, _plug) when attempt >= @max_retries do
    {:error, :max_retries_exceeded}
  end

  defp do_deliver(url, payload, headers, attempt, plug) do
    req_opts = [
      url: url,
      method: :post,
      body: payload,
      headers: headers,
      retry: false,
      receive_timeout: 10_000
    ]
    req_opts = if plug, do: Keyword.put(req_opts, :plug, plug), else: req_opts

    case Req.request(req_opts) do
      {:ok, %{status: status}} when status in 200..299 ->
        {:ok, %{status: status, attempt: attempt + 1}}

      {:ok, %{status: status}} when status in [429, 500, 502, 503, 504] ->
        delay = @base_delay_ms * :math.pow(2, attempt) |> round()
        if attempt < @max_retries - 1, do: Process.sleep(delay)
        do_deliver(url, payload, headers, attempt + 1, plug)

      {:ok, %{status: status}} ->
        {:error, %{status: status, attempt: attempt + 1}}

      {:error, reason} ->
        if attempt < @max_retries - 1 do
          delay = @base_delay_ms * :math.pow(2, attempt) |> round()
          Process.sleep(delay)
          do_deliver(url, payload, headers, attempt + 1, plug)
        else
          {:error, reason}
        end
    end
  end
end
