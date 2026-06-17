defmodule Lux.Lenses.Telegram.RateLimiter do
  @moduledoc """
  Rate limiter for Telegram Bot API requests (max ~30 req/s).
  """
  use GenServer
  defstruct max_per_second: 30, timestamps: []

  def start_link(opts \ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  def wait(pid \ __MODULE__) do
    GenServer.call(pid, :wait, :infinity)
  end

  @impl true
  def init(opts) do
    {:ok, %__MODULE__{max_per_second: opts[:max_per_second] || 30}}
  end

  @impl true
  def handle_call(:wait, _from, state) do
    now = System.monotonic_time(:millisecond)
    cutoff = now - 1000
    recent = Enum.filter(state.timestamps, &(&1 > cutoff))
    if length(recent) >= state.max_per_second do
      oldest = List.last(recent)
      Process.sleep(max(0, 1000 - (now - oldest) + 10))
    end
    t = System.monotonic_time(:millisecond)
    {:reply, :ok, %{state | timestamps: [t | Enum.filter(state.timestamps, &(&1 > t - 1000))]}}
  end
end