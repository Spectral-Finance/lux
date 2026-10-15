defmodule Lux.Web3.EventMonitor.Webhook do
  @moduledoc """
  Webhook notification dispatcher for smart contract events.

  Delivers JSON event payloads with optional HMAC-SHA256 signatures
  (`x-lux-signature-256`), configurable retries, and delivery history logging.
  """

  alias Lux.Web3.EventMonitor.Decoder.DecodedEvent

  @delivery_table :lux_web3_webhook_deliveries

  @doc """
  Initializes the ETS table for webhook delivery logs.
  """
  @spec ensure_started() :: :ok
  def ensure_started do
    case :ets.whereis(@delivery_table) do
      :undefined ->
        try do
          :ets.new(@delivery_table, [:named_table, :public, :ordered_set, read_concurrency: true])
          :ok
        rescue
          ArgumentError -> :ok
        end

      _tid ->
        :ok
    end
  end

  @doc """
  Clears all recorded webhook deliveries.
  """
  @spec reset!() :: :ok
  def reset! do
    ensure_started()
    :ets.delete_all_objects(@delivery_table)
    :ok
  end

  @doc """
  Computes the `sha256=<hex>` HMAC-SHA256 signature for a webhook payload body.
  """
  @spec compute_signature(binary(), String.t()) :: String.t()
  def compute_signature(body_json, secret) when is_binary(body_json) and is_binary(secret) do
    mac = :crypto.mac(:hmac, :sha256, secret, body_json)
    "sha256=" <> Base.encode16(mac, case: :lower)
  end

  @doc """
  Dispatches a `%DecodedEvent{}` notification to a webhook URL.
  """
  @spec deliver(String.t(), String.t(), DecodedEvent.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def deliver(subscription_id, url, %DecodedEvent{} = event, opts \\ [])
      when is_binary(url) do
    ensure_started()
    retries = Keyword.get(opts, :retries, 1)
    secret = Keyword.get(opts, :secret)

    payload = %{
      "subscription_id" => subscription_id,
      "event_id" => event.id,
      "chain" => Atom.to_string(event.chain),
      "contract_address" => event.contract_address,
      "block_number" => event.block_number,
      "tx_hash" => event.tx_hash,
      "log_index" => event.log_index,
      "event_name" => event.event_name,
      "signature" => event.signature,
      "params" => stringify_keys(event.params),
      "timestamp" => event.timestamp
    }

    body_json = Jason.encode!(payload)

    headers =
      [{"Content-Type", "application/json"}]
      |> maybe_add_signature_header(body_json, secret)

    attempt_delivery(subscription_id, url, event.id, body_json, headers, retries, opts)
  end

  @doc """
  Lists recorded webhook delivery attempts.
  """
  @spec list_deliveries(keyword()) :: [map()]
  def list_deliveries(opts \\ []) do
    ensure_started()
    sub_filter = Keyword.get(opts, :subscription_id)

    @delivery_table
    |> :ets.tab2list()
    |> Enum.map(fn {_seq, entry} -> entry end)
    |> Enum.filter(fn entry ->
      is_nil(sub_filter) or entry.subscription_id == sub_filter
    end)
  end

  defp attempt_delivery(sub_id, url, event_id, body_json, headers, retries_left, opts) do
    req_opts =
      [
        url: url,
        body: body_json,
        headers: headers
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
      |> Keyword.merge(Keyword.get(opts, :req_options, []))

    case Req.post(Req.new(req_opts)) do
      {:ok, %{status: status}} when status in 200..299 ->
        record = record_delivery(sub_id, url, event_id, :delivered, status, nil)
        {:ok, record}

      {:ok, %{status: status, body: resp_body}} ->
        if retries_left > 0 do
          attempt_delivery(sub_id, url, event_id, body_json, headers, retries_left - 1, opts)
        else
          reason = {:http_error, status, resp_body}
          _ = record_delivery(sub_id, url, event_id, :failed, status, reason)
          {:error, reason}
        end

      {:error, reason} ->
        if retries_left > 0 do
          attempt_delivery(sub_id, url, event_id, body_json, headers, retries_left - 1, opts)
        else
          _ = record_delivery(sub_id, url, event_id, :failed, nil, reason)
          {:error, reason}
        end
    end
  end

  defp record_delivery(sub_id, url, event_id, status, http_status, error) do
    seq = System.unique_integer([:positive, :monotonic])

    entry = %{
      id: seq,
      subscription_id: sub_id,
      url: url,
      event_id: event_id,
      status: status,
      http_status: http_status,
      error: error,
      timestamp: DateTime.utc_now()
    }

    :ets.insert(@delivery_table, {seq, entry})
    entry
  end

  defp maybe_add_signature_header(headers, _body_json, nil), do: headers

  defp maybe_add_signature_header(headers, body_json, secret) when is_binary(secret) do
    sig = compute_signature(body_json, secret)
    [{"x-lux-signature-256", sig} | headers]
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end
end
