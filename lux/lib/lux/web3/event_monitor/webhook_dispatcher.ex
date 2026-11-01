defmodule Lux.Web3.EventMonitor.WebhookDispatcher do
  @moduledoc """
  Webhook notification engine with cryptographic HMAC verification and retry backoff (#75).

  Dispatches event alerts to external listener endpoints when matching smart contract
  events trigger. Verifies delivery authenticity via `X-Lux-Signature: sha256=<hmac>` headers.
  """

  use GenServer
  alias Lux.Web3.EventMonitor.Schemas.{MonitoredEvent, Subscription, WebhookDelivery}

  @max_retries 3
  @initial_backoff_ms 100

  @type state :: %{
          deliveries: %{String.t() => WebhookDelivery.t()},
          http_client: module()
        }

  # --- Client API ---

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Dispatches an event notification to the subscription's configured webhook URL.
  """
  @spec dispatch(GenServer.server(), MonitoredEvent.t(), Subscription.t()) ::
          {:ok, WebhookDelivery.t()} | {:error, term()}
  def dispatch(server \\ __MODULE__, %MonitoredEvent{} = event, %Subscription{} = sub) do
    if is_binary(sub.webhook_url) and String.length(sub.webhook_url) > 0 do
      GenServer.call(server, {:dispatch, event, sub})
    else
      {:error, :no_webhook_url}
    end
  end

  @doc """
  Retrieves a delivery record by ID.
  """
  @spec get_delivery(GenServer.server(), String.t()) :: {:ok, WebhookDelivery.t()} | {:error, :not_found}
  def get_delivery(server \\ __MODULE__, delivery_id) do
    GenServer.call(server, {:get_delivery, delivery_id})
  end

  @doc """
  Lists all recorded deliveries.
  """
  @spec list_deliveries(GenServer.server(), non_neg_integer()) :: [WebhookDelivery.t()]
  def list_deliveries(server \\ __MODULE__, limit \\ 50) do
    GenServer.call(server, {:list_deliveries, limit})
  end

  @doc """
  Computes HMAC-SHA256 signature for webhook payload verification.
  """
  @spec compute_hmac_signature(String.t(), String.t()) :: String.t()
  def compute_hmac_signature(payload, secret) when is_binary(payload) and is_binary(secret) do
    :crypto.mac(:hmac, :sha256, secret, payload)
    |> Base.encode16(case: :lower)
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    http_client = Keyword.get(opts, :http_client, Req)
    {:ok, %{deliveries: %{}, http_client: http_client}}
  end

  @impl true
  def handle_call({:dispatch, event, sub}, _from, state) do
    delivery_id = "dlv_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
    now = System.system_time(:second)

    payload = build_payload(event, sub)
    json_payload = Jason.encode!(payload)
    headers = build_headers(json_payload, sub.webhook_secret)

    # Perform delivery with retry
    {status, code, err} = execute_post(state.http_client, sub.webhook_url, json_payload, headers, 0)

    delivery = %WebhookDelivery{
      id: delivery_id,
      subscription_id: sub.id,
      event_id: event.id,
      webhook_url: sub.webhook_url,
      status: status,
      attempts: 1,
      response_code: code,
      error_message: err,
      delivered_at: if(status == :delivered, do: now, else: nil),
      created_at: now
    }

    new_deliveries = Map.put(state.deliveries, delivery_id, delivery)
    {:reply, {:ok, delivery}, %{state | deliveries: new_deliveries}}
  end

  @impl true
  def handle_call({:get_delivery, id}, _from, state) do
    case Map.get(state.deliveries, id) do
      nil -> {:reply, {:error, :not_found}, state}
      dlv -> {:reply, {:ok, dlv}, state}
    end
  end

  @impl true
  def handle_call({:list_deliveries, limit}, _from, state) do
    list =
      state.deliveries
      |> Map.values()
      |> Enum.sort_by(& &1.created_at, :desc)
      |> Enum.take(limit)

    {:reply, list, state}
  end

  defp build_payload(event, sub) do
    %{
      event_id: event.id,
      subscription_id: sub.id,
      subscription_name: sub.name,
      chain: event.chain,
      chain_id: event.chain_id,
      contract_address: event.contract_address,
      event_name: event.event_name,
      event_signature: event.event_signature,
      block_number: event.block_number,
      block_hash: event.block_hash,
      tx_hash: event.tx_hash,
      log_index: event.log_index,
      decoded_params: event.decoded_params,
      timestamp: event.timestamp
    }
  end

  defp build_headers(payload, secret) do
    base = [{"content-type", "application/json"}, {"user-agent", "Lux-EventMonitor/1.0"}]

    if is_binary(secret) and String.length(secret) > 0 do
      signature = compute_hmac_signature(payload, secret)
      [{"x-lux-signature", "sha256=" <> signature} | base]
    else
      base
    end
  end

  defp execute_post(client, url, payload, headers, attempt) do
    try do
      case apply(client, :post, [url, [body: payload, headers: headers]]) do
        {:ok, %{status: status}} when status in 200..299 ->
          {:delivered, status, nil}

        {:ok, %{status: status}} ->
          if attempt < @max_retries do
            :timer.sleep(@initial_backoff_ms * (attempt + 1))
            execute_post(client, url, payload, headers, attempt + 1)
          else
            {:failed, status, "HTTP error #{status}"}
          end

        {:error, reason} ->
          if attempt < @max_retries do
            :timer.sleep(@initial_backoff_ms * (attempt + 1))
            execute_post(client, url, payload, headers, attempt + 1)
          else
            {:failed, nil, inspect(reason)}
          end
      end
    catch
      _kind, error ->
        {:failed, nil, inspect(error)}
    end
  end
end
