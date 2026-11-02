defmodule Lux.Web3.Auth.AuditLogger do
  @moduledoc """
  Security Audit Logger for Web3 Authentication and Authorization events.
  Records structured audit trails for logins, signature validations, session lifecycles,
  token-gating evaluations, and RBAC authorization decisions.
  """

  use GenServer

  @type event_type ::
          :login_success
          | :login_failure
          | :session_created
          | :session_validated
          | :session_expired
          | :session_revoked
          | :session_revoked_all
          | :signature_verified
          | :signature_verification_failed
          | :token_gate_passed
          | :token_gate_failed
          | :access_granted
          | :access_denied
          | :role_assigned
          | :role_revoked
          | atom()

  @type log_entry :: %{
          id: String.t(),
          event_type: event_type(),
          address: String.t() | nil,
          status: :ok | :error,
          details: map(),
          ip: String.t() | nil,
          user_agent: String.t() | nil,
          timestamp: DateTime.t()
        }

  # --- Client API ---

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Records an audit log entry.
  """
  @spec log(event_type(), String.t() | nil, :ok | :error, map(), keyword(), atom() | pid()) :: log_entry()
  def log(event_type, address, status, details \\ %{}, opts \\ [], server \\ __MODULE__) do
    clean_addr = if address, do: String.downcase(address), else: nil
    now = Keyword.get(opts, :as_of, DateTime.utc_now())
    ip = Keyword.get(opts, :ip)
    user_agent = Keyword.get(opts, :user_agent)

    entry = %{
      id: generate_log_id(),
      event_type: event_type,
      address: clean_addr,
      status: status,
      details: details,
      ip: ip,
      user_agent: user_agent,
      timestamp: now
    }

    if server_alive?(server) do
      GenServer.call(server, {:append, entry})
    end

    entry
  end

  @doc """
  Queries audit logs by filtering criteria:
  - `:address`: match specific wallet address
  - `:event_type`: match specific event type
  - `:status`: `:ok` or `:error`
  - `:limit`: max number of entries to return (default 100)
  """
  @spec query(keyword(), atom() | pid()) :: list(log_entry())
  def query(filters \\ [], server \\ __MODULE__) do
    if server_alive?(server) do
      GenServer.call(server, {:query, filters})
    else
      []
    end
  end

  @doc """
  Returns aggregate summary metrics of recorded events.
  """
  @spec summary(atom() | pid()) :: map()
  def summary(server \\ __MODULE__) do
    if server_alive?(server) do
      GenServer.call(server, :summary)
    else
      %{total: 0, by_event: %{}, by_status: %{ok: 0, error: 0}}
    end
  end

  @doc """
  Clears all recorded audit logs.
  """
  @spec clear(atom() | pid()) :: :ok
  def clear(server \\ __MODULE__) do
    if server_alive?(server) do
      GenServer.call(server, :clear)
    else
      :ok
    end
  end

  # --- Internal Helpers ---

  defp generate_log_id do
    "audit_" <> (:crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower))
  end

  defp server_alive?(server) when is_atom(server) do
    Process.whereis(server) != nil
  end

  defp server_alive?(server) when is_pid(server) do
    Process.alive?(server)
  end

  defp server_alive?(_), do: false

  # --- GenServer Implementation ---

  @impl true
  def init(_opts) do
    {:ok, %{logs: []}}
  end

  @impl true
  def handle_call({:append, entry}, _from, state) do
    {:reply, entry, %{state | logs: [entry | state.logs]}}
  end

  @impl true
  def handle_call({:query, filters}, _from, state) do
    address = Keyword.get(filters, :address)
    event_type = Keyword.get(filters, :event_type)
    status = Keyword.get(filters, :status)
    limit = Keyword.get(filters, :limit, 100)

    clean_addr = if address, do: String.downcase(address), else: nil

    results =
      state.logs
      |> Enum.filter(fn entry ->
        (is_nil(clean_addr) or entry.address == clean_addr) and
          (is_nil(event_type) or entry.event_type == event_type) and
          (is_nil(status) or entry.status == status)
      end)
      |> Enum.take(limit)

    {:reply, results, state}
  end

  @impl true
  def handle_call(:summary, _from, state) do
    total = length(state.logs)

    by_status =
      Enum.reduce(state.logs, %{ok: 0, error: 0}, fn entry, acc ->
        Map.update(acc, entry.status, 1, &(&1 + 1))
      end)

    by_event =
      Enum.reduce(state.logs, %{}, fn entry, acc ->
        Map.update(acc, entry.event_type, 1, &(&1 + 1))
      end)

    {:reply, %{total: total, by_status: by_status, by_event: by_event}, state}
  end

  @impl true
  def handle_call(:clear, _from, _state) do
    {:reply, :ok, %{logs: []}}
  end
end
