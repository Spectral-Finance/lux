defmodule Lux.Company.Objective do
  @moduledoc """
  Defines the structure of an objective within a company.

  An objective represents a specific goal that needs to be achieved by the company's agents.
  Each objective has:
  - A unique identifier
  - A name and description
  - Success criteria
  - A list of steps to achieve it
  - Status tracking
  - Assigned agents
  """

  @type t :: %__MODULE__{
          id: String.t(),
          name: atom(),
          description: String.t(),
          success_criteria: String.t(),
          steps: [String.t()],
          status: status(),
          assigned_agents: [String.t()],
          progress: integer(),
          started_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil,
          metadata: map(),
          input_schema: map() | nil
        }

  @type status :: :pending | :in_progress | :completed | :failed

  defstruct [
    :id,
    :name,
    :description,
    :success_criteria,
    :input_schema,
    steps: [],
    status: :pending,
    assigned_agents: [],
    progress: 0,
    started_at: nil,
    completed_at: nil,
    metadata: %{}
  ]

  @doc """
  Creates a new objective with the given attributes.
  """
  def new(attrs) when is_map(attrs) do
    objective =
      struct(__MODULE__, %{
        id: Map.get(attrs, :id, Lux.UUID.generate()),
        name: Map.fetch!(attrs, :name),
        description: Map.fetch!(attrs, :description),
        success_criteria: Map.get(attrs, :success_criteria, ""),
        steps: Map.get(attrs, :steps, []),
        input_schema: Map.get(attrs, :input_schema),
        metadata: Map.get(attrs, :metadata, %{})
      })

    {:ok, objective}
  end

  def new(_), do: {:error, :invalid_attributes}

  @doc """
  Assigns an agent to the objective.
  """
  def assign_agent(%__MODULE__{} = objective, agent_id) do
    if agent_id in objective.assigned_agents do
      {:error, :already_assigned}
    else
      {:ok, %{objective | assigned_agents: [agent_id | objective.assigned_agents]}}
    end
  end

  @doc """
  Starts the objective if it's in pending status.
  """
  def start(%__MODULE__{status: :pending} = objective) do
    if objective.assigned_agents == [] do
      {:error, :no_agents_assigned}
    else
      {:ok, %{objective | status: :in_progress, started_at: DateTime.utc_now()}}
    end
  end

  def start(%__MODULE__{}), do: {:error, :invalid_status}

  @doc """
  Updates the progress of an objective.
  Progress should be an integer between 0 and 100.
  """
  def update_progress(%__MODULE__{status: :in_progress} = objective, progress)
      when is_integer(progress) and progress >= 0 and progress <= 100 do
    {:ok, %{objective | progress: progress}}
  end

  def update_progress(%__MODULE__{}, _), do: {:error, :invalid_progress}

  @doc """
  Completes the objective if it's in progress.
  """
  def complete(%__MODULE__{status: :in_progress} = objective) do
    {:ok, %{objective | status: :completed, progress: 100, completed_at: DateTime.utc_now()}}
  end

  def complete(%__MODULE__{}), do: {:error, :invalid_status}

  @doc """
  Marks the objective as failed with an optional reason.
  """
  def fail(objective, reason \\ nil)

  def fail(%__MODULE__{status: :in_progress} = objective, reason) do
    metadata = Map.put(objective.metadata, :failure_reason, reason)

    {:ok, %{objective | status: :failed, completed_at: DateTime.utc_now(), metadata: metadata}}
  end

  def fail(%__MODULE__{}, _), do: {:error, :invalid_status}

  @doc """
  Returns true if the objective can be started.
  """
  def can_start?(%__MODULE__{} = objective) do
    objective.status == :pending and objective.assigned_agents != []
  end

  @doc """
  Returns true if the objective is active (in progress).
  """
  def active?(%__MODULE__{} = objective) do
    objective.status == :in_progress
  end

  @doc """
  Returns true if the objective is completed.
  """
  def completed?(%__MODULE__{} = objective) do
    objective.status == :completed
  end

  @doc """
  Returns true if the objective has failed.
  """
  def failed?(%__MODULE__{} = objective) do
    objective.status == :failed
  end

  @doc """
  Returns the duration of the objective if it has started.
  Returns nil if the objective hasn't started.
  """
  def duration(%__MODULE__{started_at: nil}), do: nil

  def duration(%__MODULE__{started_at: started_at, completed_at: nil}) do
    DateTime.diff(DateTime.utc_now(), started_at)
  end

  def duration(%__MODULE__{started_at: started_at, completed_at: completed_at}) do
    DateTime.diff(completed_at, started_at)
  end
end
