defmodule Lux.Prisms.YouTube.Community.PostScheduler do
  @moduledoc """
  Community post scheduling and campaign management.
  """

  use GenServer

  defstruct [:posts, :campaigns]

  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def schedule_post(pid \\ __MODULE__, post) do
    GenServer.call(pid, {:schedule, post})
  end

  def cancel_post(pid \\ __MODULE__, post_id) do
    GenServer.call(pid, {:cancel, post_id})
  end

  def get_due_posts(pid \\ __MODULE__) do
    GenServer.call(pid, :get_due)
  end

  def create_campaign(pid \\ __MODULE__, campaign) do
    GenServer.call(pid, {:create_campaign, campaign})
  end

  def list_posts(pid \\ __MODULE__) do
    GenServer.call(pid, :list_posts)
  end

  def list_campaigns(pid \\ __MODULE__) do
    GenServer.call(pid, :list_campaigns)
  end

  @impl true
  def init(_opts), do: {:ok, %__MODULE__{posts: [], campaigns: []}}

  @impl true
  def handle_call({:schedule, post}, _from, state) do
    id = post[:id] || gen_id()
    entry = %{
      id: id,
      text: post[:text],
      image_url: post[:image_url],
      poll: post[:poll],
      scheduled_at: post[:scheduled_at],
      campaign_id: post[:campaign_id],
      status: :scheduled,
      platforms: post[:platforms] || [:youtube]
    }
    posts = [entry | state.posts] |> Enum.sort_by(& &1.scheduled_at, DateTime)
    {:reply, {:ok, entry}, %{state | posts: posts}}
  end

  @impl true
  def handle_call({:cancel, post_id}, _from, state) do
    case Enum.find(state.posts, &(&1.id == post_id)) do
      nil -> {:reply, {:error, :not_found}, state}
      _ ->
        posts = Enum.reject(state.posts, &(&1.id == post_id))
        {:reply, :ok, %{state | posts: posts}}
    end
  end

  @impl true
  def handle_call(:get_due, _from, state) do
    now = DateTime.utc_now()
    {due, remaining} = Enum.split_with(state.posts, fn p ->
      p.status == :scheduled && DateTime.compare(p.scheduled_at, now) in [:lt, :eq]
    end)
    {:reply, {:ok, due}, %{state | posts: remaining}}
  end

  @impl true
  def handle_call({:create_campaign, campaign}, _from, state) do
    id = campaign[:id] || gen_id()
    entry = %{
      id: id,
      name: campaign[:name],
      description: campaign[:description] || "",
      start_date: campaign[:start_date],
      end_date: campaign[:end_date],
      status: :active,
      created_at: DateTime.utc_now()
    }
    {:reply, {:ok, entry}, %{state | campaigns: [entry | state.campaigns]}}
  end

  @impl true
  def handle_call(:list_posts, _from, state) do
    {:reply, {:ok, state.posts}, state}
  end

  @impl true
  def handle_call(:list_campaigns, _from, state) do
    {:reply, {:ok, state.campaigns}, state}
  end

  defp gen_id, do: :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
end
