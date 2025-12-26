defmodule Lux.TwitterAutomation.Supervisor do
  @moduledoc """
  Top-level supervisor for Twitter Automation system.

  Manages all automation components:
  - QueueManager
  - Scheduler
  - RulesEngine
  - ContentCalendar
  - FollowManager
  - DMManager
  """
  use Supervisor
  require Logger

  alias Lux.TwitterAutomation.{
    Storage,
    QueueManager,
    Scheduler,
    RulesEngine,
    ContentCalendar,
    FollowManager,
    DMManager
  }

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting TwitterAutomation.Supervisor")

    # Initialize storage tables (ETS/DETS)
    Storage.init()

    children = [
      QueueManager,
      Scheduler,
      RulesEngine,
      ContentCalendar,
      FollowManager,
      DMManager
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
