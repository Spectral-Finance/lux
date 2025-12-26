defmodule Lux.TwitterAutomation.FollowManager do
  @moduledoc """
  Automated follow/unfollow management with safety features.

  Features:
  - Auto follow-back new followers
  - Whitelist (never unfollow)
  - Blacklist (never follow)
  - Rate-limited operations
  - Configurable auto-follow-back
  """

  use GenServer
  require Logger

  alias Lux.TwitterAutomation.QueueManager

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Follow a user"
  def follow_user(user_id_or_username, authenticated_user_id) do
    GenServer.call(__MODULE__, {:follow_user, user_id_or_username, authenticated_user_id})
  end

  @doc "Unfollow a user"
  def unfollow_user(user_id_or_username, authenticated_user_id) do
    GenServer.call(__MODULE__, {:unfollow_user, user_id_or_username, authenticated_user_id})
  end

  @doc "Enable auto follow-back"
  def enable_auto_follow_back do
    GenServer.call(__MODULE__, {:set_auto_follow_back, true})
  end

  @doc "Disable auto follow-back"
  def disable_auto_follow_back do
    GenServer.call(__MODULE__, {:set_auto_follow_back, false})
  end

  @doc "Add user to whitelist (never unfollow)"
  def add_to_whitelist(user_id) do
    GenServer.call(__MODULE__, {:add_to_whitelist, user_id})
  end

  @doc "Add user to blacklist (never follow)"
  def add_to_blacklist(user_id) do
    GenServer.call(__MODULE__, {:add_to_blacklist, user_id})
  end

  @doc "Remove from whitelist"
  def remove_from_whitelist(user_id) do
    GenServer.call(__MODULE__, {:remove_from_whitelist, user_id})
  end

  @doc "Remove from blacklist"
  def remove_from_blacklist(user_id) do
    GenServer.call(__MODULE__, {:remove_from_blacklist, user_id})
  end

  @doc "Get follow status"
  def get_follow_status do
    GenServer.call(__MODULE__, :get_follow_status)
  end

  @doc "Process new follower (for auto follow-back)"
  def process_new_follower(follower_id, authenticated_user_id) do
    GenServer.cast(__MODULE__, {:process_new_follower, follower_id, authenticated_user_id})
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    {:ok,
     %{
       auto_follow_back: false,
       whitelist: MapSet.new(),
       blacklist: MapSet.new(),
       follow_history: %{},  # Track follows per day
       unfollow_history: %{}  # Track unfollows per day
     }}
  end

  @impl true
  def handle_call({:follow_user, target_user_id, source_user_id}, _from, state) do
    if MapSet.member?(state.blacklist, target_user_id) do
      Logger.warn("Cannot follow blacklisted user #{target_user_id}")
      {:reply, {:error, :blacklisted}, state}
    else
      case QueueManager.enqueue(:follow_user, %{
             user_id: source_user_id,
             target_user_id: target_user_id
           }, :normal) do
        {:ok, queue_id} ->
          new_state = track_follow(state, target_user_id)
          Logger.info("Queued follow for user #{target_user_id}")
          {:reply, {:ok, queue_id}, new_state}

        error ->
          {:reply, error, state}
      end
    end
  end

  @impl true
  def handle_call({:unfollow_user, target_user_id, source_user_id}, _from, state) do
    if MapSet.member?(state.whitelist, target_user_id) do
      Logger.warn("Cannot unfollow whitelisted user #{target_user_id}")
      {:reply, {:error, :whitelisted}, state}
    else
      case QueueManager.enqueue(:unfollow_user, %{
             source_user_id: source_user_id,
             target_user_id: target_user_id
           }, :low) do
        {:ok, queue_id} ->
          new_state = track_unfollow(state, target_user_id)
          Logger.info("Queued unfollow for user #{target_user_id}")
          {:reply, {:ok, queue_id}, new_state}

        error ->
          {:reply, error, state}
      end
    end
  end

  @impl true
  def handle_call({:set_auto_follow_back, enabled}, _from, state) do
    Logger.info("Auto follow-back #{if enabled, do: "enabled", else: "disabled"}")
    {:reply, :ok, %{state | auto_follow_back: enabled}}
  end

  @impl true
  def handle_call({:add_to_whitelist, user_id}, _from, state) do
    new_whitelist = MapSet.put(state.whitelist, user_id)
    Logger.info("Added user #{user_id} to whitelist")
    {:reply, :ok, %{state | whitelist: new_whitelist}}
  end

  @impl true
  def handle_call({:add_to_blacklist, user_id}, _from, state) do
    new_blacklist = MapSet.put(state.blacklist, user_id)
    Logger.info("Added user #{user_id} to blacklist")
    {:reply, :ok, %{state | blacklist: new_blacklist}}
  end

  @impl true
  def handle_call({:remove_from_whitelist, user_id}, _from, state) do
    new_whitelist = MapSet.delete(state.whitelist, user_id)
    {:reply, :ok, %{state | whitelist: new_whitelist}}
  end

  @impl true
  def handle_call({:remove_from_blacklist, user_id}, _from, state) do
    new_blacklist = MapSet.delete(state.blacklist, user_id)
    {:reply, :ok, %{state | blacklist: new_blacklist}}
  end

  @impl true
  def handle_call(:get_follow_status, _from, state) do
    today = Date.utc_today()
    follows_today = Map.get(state.follow_history, today, 0)
    unfollows_today = Map.get(state.unfollow_history, today, 0)

    status = %{
      auto_follow_back: state.auto_follow_back,
      whitelist_size: MapSet.size(state.whitelist),
      blacklist_size: MapSet.size(state.blacklist),
      follows_today: follows_today,
      unfollows_today: unfollows_today
    }

    {:reply, status, state}
  end

  @impl true
  def handle_cast({:process_new_follower, follower_id, authenticated_user_id}, state) do
    if state.auto_follow_back and not MapSet.member?(state.blacklist, follower_id) do
      Logger.info("Auto follow-back triggered for #{follower_id}")

      QueueManager.enqueue(:follow_user, %{
        user_id: authenticated_user_id,
        target_user_id: follower_id
      }, :normal)

      new_state = track_follow(state, follower_id)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  ## Private Functions

  defp track_follow(state, _user_id) do
    today = Date.utc_today()
    current_count = Map.get(state.follow_history, today, 0)
    new_history = Map.put(state.follow_history, today, current_count + 1)

    # Clean old history (keep last 7 days)
    cleaned_history = clean_history(new_history, 7)

    %{state | follow_history: cleaned_history}
  end

  defp track_unfollow(state, _user_id) do
    today = Date.utc_today()
    current_count = Map.get(state.unfollow_history, today, 0)
    new_history = Map.put(state.unfollow_history, today, current_count + 1)

    # Clean old history
    cleaned_history = clean_history(new_history, 7)

    %{state | unfollow_history: cleaned_history}
  end

  defp clean_history(history, days_to_keep) do
    cutoff = Date.add(Date.utc_today(), -days_to_keep)

    Enum.filter(history, fn {date, _count} ->
      Date.compare(date, cutoff) in [:gt, :eq]
    end)
    |> Map.new()
  end
end
