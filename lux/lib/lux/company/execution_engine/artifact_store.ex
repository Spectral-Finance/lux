defmodule Lux.Company.ExecutionEngine.ArtifactStore do
  @moduledoc """
  In-memory store for managing artifacts produced during objective execution.

  This module is responsible for:
  - Storing and retrieving artifacts in memory
  - Tracking artifact metadata and relationships
  - Providing access to artifacts across steps
  - Extensive logging of artifact operations
  """

  use GenServer

  require Logger

  @type artifact_id :: String.t()
  @type step_id :: String.t()
  @type task_id :: String.t()

  @type artifact :: %{
          id: artifact_id(),
          name: String.t(),
          content: term(),
          content_type: String.t(),
          metadata: map(),
          created_by: task_id(),
          created_at: DateTime.t(),
          step_id: step_id(),
          tags: [String.t()]
        }

  @type state :: %{
          objective_id: String.t(),
          artifacts: %{artifact_id() => artifact()},
          step_artifacts: %{step_id() => MapSet.t(artifact_id())},
          company_pid: pid()
        }

  # Client API

  @doc """
  Starts a new ArtifactStore for an objective.

  ## Options
  - :objective_id - The ID of the objective these artifacts belong to
  - :company_pid - PID of the company process for notifications
  """
  def start_link(opts) do
    objective_id = Keyword.fetch!(opts, :objective_id)
    name = via_tuple(objective_id)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Stores a new artifact.

  ## Parameters
  - store: The ArtifactStore pid
  - name: Name of the artifact
  - content: The artifact content (any term)
  - content_type: MIME type or format identifier
  - opts: Additional options
    - :metadata - Additional metadata map
    - :tags - List of tags
    - :step_id - ID of the step that created the artifact
    - :task_id - ID of the task that created the artifact
  """
  def store_artifact(store, name, content, content_type, opts \\ []) do
    GenServer.call(store, {:store_artifact, name, content, content_type, opts})
  end

  @doc """
  Retrieves an artifact by ID.
  """
  def get_artifact(store, artifact_id) do
    GenServer.call(store, {:get_artifact, artifact_id})
  end

  @doc """
  Lists all artifacts for a specific step.
  """
  def list_step_artifacts(store, step_id) do
    GenServer.call(store, {:list_step_artifacts, step_id})
  end

  @doc """
  Lists all artifacts with optional filtering.

  ## Options
  - :tags - List of tags to filter by (all must match)
  - :content_type - Filter by content type
  - :created_by - Filter by task ID
  """
  def list_artifacts(store, opts \\ []) do
    GenServer.call(store, {:list_artifacts, opts})
  end

  @doc """
  Updates artifact metadata.
  """
  def update_metadata(store, artifact_id, metadata) do
    GenServer.call(store, {:update_metadata, artifact_id, metadata})
  end

  @doc """
  Adds tags to an artifact.
  """
  def add_tags(store, artifact_id, tags) do
    GenServer.call(store, {:add_tags, artifact_id, tags})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    Logger.debug("Initializing ArtifactStore with opts: #{inspect(opts)}")

    state = %{
      objective_id: Keyword.fetch!(opts, :objective_id),
      company_pid: Keyword.fetch!(opts, :company_pid),
      artifacts: %{},
      step_artifacts: %{}
    }

    Logger.debug("Initial state: #{inspect(state)}")
    {:ok, state}
  end

  @impl true
  def handle_call({:store_artifact, name, content, content_type, opts}, _from, state) do
    Logger.debug("Storing artifact '#{name}' of type #{content_type}")
    Logger.debug("Artifact options: #{inspect(opts)}")

    artifact_id = "artifact_#{:erlang.unique_integer([:positive])}"
    step_id = Keyword.get(opts, :step_id)
    task_id = Keyword.get(opts, :task_id)

    artifact = %{
      id: artifact_id,
      name: name,
      content: content,
      content_type: content_type,
      metadata: Keyword.get(opts, :metadata, %{}),
      created_by: task_id,
      created_at: DateTime.utc_now(),
      step_id: step_id,
      tags: Keyword.get(opts, :tags, [])
    }

    Logger.debug("Created artifact: #{inspect(artifact)}")

    new_state =
      state
      |> put_in([:artifacts, artifact_id], artifact)
      |> maybe_add_to_step(step_id, artifact_id)

    notify_company(new_state, {:artifact_stored, artifact})
    {:reply, {:ok, artifact_id}, new_state}
  end

  def handle_call({:get_artifact, artifact_id}, _from, state) do
    Logger.debug("Retrieving artifact #{artifact_id}")

    case Map.get(state.artifacts, artifact_id) do
      nil ->
        Logger.warning("Artifact #{artifact_id} not found")
        {:reply, {:error, :not_found}, state}

      artifact ->
        Logger.debug("Found artifact: #{inspect(artifact)}")
        {:reply, {:ok, artifact}, state}
    end
  end

  def handle_call({:list_step_artifacts, step_id}, _from, state) do
    Logger.debug("Listing artifacts for step #{step_id}")

    artifact_ids = Map.get(state.step_artifacts, step_id, MapSet.new())

    artifacts =
      artifact_ids
      |> Enum.map(&Map.get(state.artifacts, &1))
      |> Enum.reject(&is_nil/1)

    Logger.debug("Found #{length(artifacts)} artifacts for step #{step_id}")
    {:reply, {:ok, artifacts}, state}
  end

  def handle_call({:list_artifacts, opts}, _from, state) do
    Logger.debug("Listing artifacts with options: #{inspect(opts)}")

    artifacts =
      state.artifacts
      |> Map.values()
      |> filter_artifacts(opts)

    Logger.debug("Found #{length(artifacts)} matching artifacts")
    {:reply, {:ok, artifacts}, state}
  end

  def handle_call({:update_metadata, artifact_id, metadata}, _from, state) do
    Logger.debug("Updating metadata for artifact #{artifact_id}: #{inspect(metadata)}")

    case get_artifact_from_state(state, artifact_id) do
      {:ok, artifact} ->
        updated_artifact = %{artifact | metadata: Map.merge(artifact.metadata, metadata)}

        new_state = put_in(state.artifacts[artifact_id], updated_artifact)
        notify_company(new_state, {:artifact_updated, updated_artifact})
        {:reply, :ok, new_state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:add_tags, artifact_id, tags}, _from, state) do
    Logger.debug("Adding tags #{inspect(tags)} to artifact #{artifact_id}")

    case get_artifact_from_state(state, artifact_id) do
      {:ok, artifact} ->
        updated_artifact = %{artifact | tags: Enum.uniq(artifact.tags ++ tags)}

        new_state = put_in(state.artifacts[artifact_id], updated_artifact)
        notify_company(new_state, {:artifact_updated, updated_artifact})
        {:reply, :ok, new_state}

      error ->
        {:reply, error, state}
    end
  end

  # Private Functions

  defp via_tuple(objective_id) do
    {:via, Registry, {Module.concat(objective_id, ArtifactRegistry), "artifact_store"}}
  end

  defp maybe_add_to_step(state, nil, _artifact_id), do: state

  defp maybe_add_to_step(state, step_id, artifact_id) do
    step_artifacts = Map.get(state.step_artifacts, step_id, MapSet.new())
    put_in(state.step_artifacts[step_id], MapSet.put(step_artifacts, artifact_id))
  end

  defp get_artifact_from_state(state, artifact_id) do
    case Map.get(state.artifacts, artifact_id) do
      nil -> {:error, :not_found}
      artifact -> {:ok, artifact}
    end
  end

  defp filter_artifacts(artifacts, opts) do
    artifacts
    |> filter_by_tags(Keyword.get(opts, :tags))
    |> filter_by_content_type(Keyword.get(opts, :content_type))
    |> filter_by_task(Keyword.get(opts, :created_by))
  end

  defp filter_by_tags(artifacts, nil), do: artifacts

  defp filter_by_tags(artifacts, tags) do
    Enum.filter(artifacts, fn artifact ->
      Enum.all?(tags, &(&1 in artifact.tags))
    end)
  end

  defp filter_by_content_type(artifacts, nil), do: artifacts

  defp filter_by_content_type(artifacts, content_type) do
    Enum.filter(artifacts, &(&1.content_type == content_type))
  end

  defp filter_by_task(artifacts, nil), do: artifacts

  defp filter_by_task(artifacts, task_id) do
    Enum.filter(artifacts, &(&1.created_by == task_id))
  end

  defp notify_company(state, event) do
    send(state.company_pid, {:artifact_store_update, state.objective_id, event})
  end
end
