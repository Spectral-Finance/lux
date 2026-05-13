defmodule Lux.Web3.EventMonitor.WebhookNotifier do
  @moduledoc """
  Delivers normalized smart-contract events to webhook consumers.
  """

  alias Lux.Web3.EventMonitor.Event

  @type request_fun :: (String.t(), map(), keyword() -> {:ok, any()} | {:error, any()})

  @spec payload(Event.t()) :: map()
  def payload(%Event{} = event) do
    %{
      subscription_id: event.subscription_id,
      chain_id: event.chain_id,
      contract_address: event.contract_address,
      block_number: event.block_number,
      transaction_hash: event.transaction_hash,
      log_index: event.log_index,
      topics: event.topics,
      data: event.data,
      decoded: event.decoded,
      metadata: event.metadata
    }
  end

  @spec notify(Event.t(), String.t(), keyword()) :: {:ok, any()} | {:error, any()}
  def notify(%Event{} = event, webhook_url, opts \\ []) when is_binary(webhook_url) do
    body = payload(event)
    headers = [{"content-type", "application/json"}] ++ signature_headers(body, opts[:secret])
    request_fun = Keyword.get(opts, :request_fun, &default_request/3)

    request_fun.(webhook_url, body, headers: headers)
  end

  defp signature_headers(_payload, nil), do: []

  defp signature_headers(payload, secret) when is_binary(secret) do
    encoded = Jason.encode!(payload)
    signature = :crypto.mac(:hmac, :sha256, secret, encoded) |> Base.encode16(case: :lower)
    [{"x-lux-event-signature", "sha256=#{signature}"}]
  end

  defp default_request(url, payload, opts) do
    headers = Keyword.get(opts, :headers, [])

    case Req.post(url, json: payload, headers: headers) do
      {:ok, %{status: status} = response} when status in 200..299 -> {:ok, response}
      {:ok, response} -> {:error, response}
      {:error, error} -> {:error, error}
    end
  end
end
