defmodule Lux.Company.Objectives do
  @moduledoc """
  Context module for managing objectives within a company.

  This module provides functions for:
  - Creating and managing objectives
  - Assigning agents to objectives
  - Tracking objective progress and status
  - Managing objective lifecycle (start, complete, fail)
  """

  alias Lux.Company.Objective

  @doc """
  Creates a new objective with the given attributes.

  ## Required Attributes
  - `:name` - The name of the objective (atom)
  - `:description` - A description of what needs to be achieved

  ## Optional Attributes
  - `:id` - A unique identifier (generated if not provided)
  - `:success_criteria` - Criteria for determining success
  - `:steps` - List of steps to achieve the objective
  - `:metadata` - Additional metadata as a map

  ## Examples

      iex> Objectives.create(%{
      ...>   name: :create_blog_post,
      ...>   description: "Create a well-researched blog post",
      ...>   success_criteria: "Published post with >1000 views",
      ...>   steps: ["Research", "Write", "Edit", "Publish"]
      ...> })
      {:ok, %Objective{}}

      iex> Objectives.create(%{name: :invalid})
      {:error, :invalid_attributes}
  """
  def create(attrs) when is_map(attrs) do
    objective =
      struct(Objective, %{
        id: Map.get(attrs, :id, Lux.UUID.generate()),
        name: Map.fetch!(attrs, :name),
        description: Map.fetch!(attrs, :description),
        success_criteria: Map.get(attrs, :success_criteria, ""),
        steps: Map.get(attrs, :steps, []),
        metadata: Map.get(attrs, :metadata, %{})
      })

    {:ok, objective}
  rescue
    KeyError -> {:error, :invalid_attributes}
  end

  def create(_), do: {:error, :invalid_attributes}

  @doc """
  Assigns an agent to the objective.

  Returns an error if the agent is already assigned.

  ## Examples

      iex> Objectives.assign_agent(objective, "agent-123")
      {:ok, %Objective{}}

      iex> Objectives.assign_agent(objective, "already-assigned")
      {:error, :already_assigned}
  """
  def assign_agent(%Objective{} = objective, agent_id) do
    if agent_id in objective.assigned_agents do
      {:error, :already_assigned}
    else
      {:ok, %{objective | assigned_agents: [agent_id | objective.assigned_agents]}}
    end
  end

  @doc """
  Starts the objective if it's in pending status and has assigned agents.

  ## Examples

      iex> Objectives.start(objective_with_agents)
      {:ok, %Objective{status: :in_progress}}

      iex> Objectives.start(objective_without_agents)
      {:error, :no_agents_assigned}

      iex> Objectives.start(already_started_objective)
      {:error, :invalid_status}
  """
  def start(%Objective{status: :pending} = objective) do
    if objective.assigned_agents == [] do
      {:error, :no_agents_assigned}
    else
      {:ok, %{objective | status: :in_progress, started_at: DateTime.utc_now()}}
    end
  end

  def start(%Objective{}), do: {:error, :invalid_status}

  @doc """
  Updates the progress of an objective.
  Progress should be an integer between 0 and 100.

  ## Examples

      iex> Objectives.update_progress(objective, 50)
      {:ok, %Objective{progress: 50}}

      iex> Objectives.update_progress(objective, 101)
      {:error, :invalid_progress}
  """
  def update_progress(%Objective{status: :in_progress} = objective, progress)
      when is_integer(progress) and progress >= 0 and progress <= 100 do
    {:ok, %{objective | progress: progress}}
  end

  def update_progress(%Objective{}, _), do: {:error, :invalid_progress}

  @doc """
  Completes the objective if it's in progress.

  ## Examples

      iex> Objectives.complete(in_progress_objective)
      {:ok, %Objective{status: :completed}}

      iex> Objectives.complete(pending_objective)
      {:error, :invalid_status}
  """
  def complete(%Objective{status: :in_progress} = objective) do
    {:ok, %{objective | status: :completed, progress: 100, completed_at: DateTime.utc_now()}}
  end

  def complete(%Objective{}), do: {:error, :invalid_status}

  @doc """
  Marks the objective as failed with an optional reason.

  ## Examples

      iex> Objectives.fail(objective, "Resource unavailable")
      {:ok, %Objective{status: :failed}}

      iex> Objectives.fail(completed_objective)
      {:error, :invalid_status}
  """
  def fail(objective, reason \\ nil)

  def fail(%Objective{status: :in_progress} = objective, reason) do
    metadata = Map.put(objective.metadata, :failure_reason, reason)
    {:ok, %{objective | status: :failed, completed_at: DateTime.utc_now(), metadata: metadata}}
  end

  def fail(%Objective{}, _reason), do: {:error, :invalid_status}

  @doc """
  Returns true if the objective can be started.
  """
  def can_start?(%Objective{} = objective) do
    objective.status == :pending and objective.assigned_agents != []
  end

  @doc """
  Returns true if the objective is active (in progress).
  """
  def active?(%Objective{} = objective) do
    objective.status == :in_progress
  end

  @doc """
  Returns true if the objective is completed.
  """
  def completed?(%Objective{} = objective) do
    objective.status == :completed
  end

  @doc """
  Returns true if the objective has failed.
  """
  def failed?(%Objective{} = objective) do
    objective.status == :failed
  end

  @doc """
  Returns the duration of the objective if it has started.
  Returns nil if the objective hasn't started.

  ## Examples

      iex> Objectives.duration(started_objective)
      3600  # seconds

      iex> Objectives.duration(pending_objective)
      nil
  """
  def duration(%Objective{started_at: nil}), do: nil

  def duration(%Objective{started_at: started_at, completed_at: nil}) do
    DateTime.diff(DateTime.utc_now(), started_at)
  end

  def duration(%Objective{started_at: started_at, completed_at: completed_at}) do
    DateTime.diff(completed_at, started_at)
  end
end
