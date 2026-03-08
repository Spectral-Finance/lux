defmodule Lux.Prisms.Twitter.AutoReply do
  @moduledoc """
  Auto-reply management for Twitter interactions.

  Features:
  - Template-based replies with variable substitution
  - Keyword matching triggers
  - Reply cooldowns per user
  - Blocklist/allowlist filtering
  """

  use GenServer

  defstruct [:templates, :cooldowns, :blocklist, :reply_log, :cooldown_seconds]

  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def add_template(pid \\ __MODULE__, template) do
    GenServer.call(pid, {:add_template, template})
  end

  def remove_template(pid \\ __MODULE__, template_id) do
    GenServer.call(pid, {:remove_template, template_id})
  end

  def find_reply(pid \\ __MODULE__, tweet) do
    GenServer.call(pid, {:find_reply, tweet})
  end

  def block_user(pid \\ __MODULE__, user_id) do
    GenServer.call(pid, {:block_user, user_id})
  end

  def list_templates(pid \\ __MODULE__) do
    GenServer.call(pid, :list_templates)
  end

  @impl true
  def init(opts) do
    {:ok, %__MODULE__{
      templates: [],
      cooldowns: %{},
      blocklist: MapSet.new(),
      reply_log: [],
      cooldown_seconds: opts[:cooldown_seconds] || 300
    }}
  end

  @impl true
  def handle_call({:add_template, template}, _from, state) do
    id = template[:id] || :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    entry = %{
      id: id,
      keywords: template[:keywords] || [],
      reply_text: template[:reply_text],
      variables: template[:variables] || [],
      priority: template[:priority] || 0,
      enabled: template[:enabled] != false
    }
    templates = [entry | state.templates] |> Enum.sort_by(& &1.priority, :desc)
    {:reply, {:ok, entry}, %{state | templates: templates}}
  end

  @impl true
  def handle_call({:remove_template, template_id}, _from, state) do
    templates = Enum.reject(state.templates, &(&1.id == template_id))
    {:reply, :ok, %{state | templates: templates}}
  end

  @impl true
  def handle_call({:find_reply, tweet}, _from, state) do
    user_id = tweet[:author_id]

    cond do
      MapSet.member?(state.blocklist, user_id) ->
        {:reply, {:ok, nil}, state}

      in_cooldown?(state.cooldowns, user_id, state.cooldown_seconds) ->
        {:reply, {:ok, nil}, state}

      true ->
        text = String.downcase(tweet[:text] || "")
        matching = state.templates
        |> Enum.filter(& &1.enabled)
        |> Enum.find(fn t ->
          Enum.any?(t.keywords, &String.contains?(text, String.downcase(&1)))
        end)

        case matching do
          nil ->
            {:reply, {:ok, nil}, state}
          template ->
            reply = render_template(template.reply_text, tweet)
            now = System.system_time(:second)
            cooldowns = Map.put(state.cooldowns, user_id, now)
            log = [%{tweet_id: tweet[:id], template_id: template.id, at: now} | state.reply_log]
            {:reply, {:ok, %{reply_text: reply, template_id: template.id}}, %{state | cooldowns: cooldowns, reply_log: log}}
        end
    end
  end

  @impl true
  def handle_call({:block_user, user_id}, _from, state) do
    {:reply, :ok, %{state | blocklist: MapSet.put(state.blocklist, user_id)}}
  end

  @impl true
  def handle_call(:list_templates, _from, state) do
    {:reply, {:ok, state.templates}, state}
  end

  defp in_cooldown?(cooldowns, user_id, cooldown_seconds) do
    case Map.get(cooldowns, user_id) do
      nil -> false
      last_time -> System.system_time(:second) - last_time < cooldown_seconds
    end
  end

  defp render_template(text, tweet) do
    text
    |> String.replace("{{author}}", tweet[:author_name] || "")
    |> String.replace("{{username}}", tweet[:author_username] || "")
  end
end
