defmodule Lux.Prisms.Discord.Moderation do
  @moduledoc """
  Moderation prism: content filtering, timeouts, bans, warnings.
  """

  alias Lux.Integrations.Discord.Client

  use GenServer

  defstruct [:filters, :warnings, :action_log]

  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  # Content filtering

  def add_filter(pid \\ __MODULE__, filter) do
    GenServer.call(pid, {:add_filter, filter})
  end

  def check_content(pid \\ __MODULE__, text) do
    GenServer.call(pid, {:check_content, text})
  end

  def list_filters(pid \\ __MODULE__) do
    GenServer.call(pid, :list_filters)
  end

  # Discord API moderation

  def timeout_user(guild_id, user_id, duration_seconds, opts \\ %{}) do
    until = DateTime.utc_now() |> DateTime.add(duration_seconds) |> DateTime.to_iso8601()
    Client.request(:patch, "/guilds/#{guild_id}/members/#{user_id}",
      Map.merge(opts, %{json: %{communication_disabled_until: until}}))
  end

  def remove_timeout(guild_id, user_id, opts \\ %{}) do
    Client.request(:patch, "/guilds/#{guild_id}/members/#{user_id}",
      Map.merge(opts, %{json: %{communication_disabled_until: nil}}))
  end

  def ban_user(guild_id, user_id, params \\ %{}, opts \\ %{}) do
    body = %{}
    |> maybe_put(:delete_message_seconds, params[:delete_message_seconds])

    Client.request(:put, "/guilds/#{guild_id}/bans/#{user_id}", Map.merge(opts, %{json: body}))
  end

  def unban_user(guild_id, user_id, opts \\ %{}) do
    Client.request(:delete, "/guilds/#{guild_id}/bans/#{user_id}", opts)
  end

  def kick_user(guild_id, user_id, opts \\ %{}) do
    Client.request(:delete, "/guilds/#{guild_id}/members/#{user_id}", opts)
  end

  def warn_user(pid \\ __MODULE__, user_id, reason) do
    GenServer.call(pid, {:warn, user_id, reason})
  end

  def get_warnings(pid \\ __MODULE__, user_id) do
    GenServer.call(pid, {:get_warnings, user_id})
  end

  def get_action_log(pid \\ __MODULE__) do
    GenServer.call(pid, :get_action_log)
  end

  # Server

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{
      filters: default_filters(),
      warnings: %{},
      action_log: []
    }}
  end

  @impl true
  def handle_call({:add_filter, filter}, _from, state) do
    entry = %{
      id: gen_id(),
      pattern: filter[:pattern],
      action: filter[:action] || :delete,
      severity: filter[:severity] || :medium
    }
    {:reply, {:ok, entry}, %{state | filters: [entry | state.filters]}}
  end

  @impl true
  def handle_call({:check_content, text}, _from, state) do
    violations = state.filters
    |> Enum.filter(fn filter ->
      case filter.pattern do
        %Regex{} = r -> Regex.match?(r, text)
        s when is_binary(s) -> String.contains?(String.downcase(text), String.downcase(s))
        _ -> false
      end
    end)

    result = if violations == [] do
      %{clean: true, violations: []}
    else
      %{clean: false, violations: Enum.map(violations, &Map.take(&1, [:id, :action, :severity]))}
    end

    {:reply, {:ok, result}, state}
  end

  @impl true
  def handle_call(:list_filters, _from, state) do
    {:reply, {:ok, state.filters}, state}
  end

  @impl true
  def handle_call({:warn, user_id, reason}, _from, state) do
    warning = %{reason: reason, at: DateTime.utc_now()}
    warnings = Map.update(state.warnings, user_id, [warning], &[warning | &1])
    count = length(Map.get(warnings, user_id))
    log = [%{action: :warn, user_id: user_id, reason: reason, at: DateTime.utc_now()} | state.action_log]
    {:reply, {:ok, %{user_id: user_id, warning_count: count, reason: reason}},
     %{state | warnings: warnings, action_log: log}}
  end

  @impl true
  def handle_call({:get_warnings, user_id}, _from, state) do
    {:reply, {:ok, Map.get(state.warnings, user_id, [])}, state}
  end

  @impl true
  def handle_call(:get_action_log, _from, state) do
    {:reply, {:ok, state.action_log}, state}
  end

  defp default_filters do
    [
      %{id: "spam_links", pattern: ~r/discord\.gg\/\w+/i, action: :delete, severity: :high},
      %{id: "all_caps", pattern: ~r/^[A-Z\s!]{20,}$/, action: :warn, severity: :low}
    ]
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp gen_id, do: :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
end
