defmodule Lux.Company.ExecutionEngine.ArtifactStoreTest do
  use UnitCase, async: true

  alias Lux.Company.ExecutionEngine.ArtifactStore

  setup do
    # Create a unique registry for test isolation
    registry_name = :"test_registry_#{:erlang.unique_integer([:positive])}"
    {:ok, _} = Registry.start_link(keys: :unique, name: registry_name)

    # Create a mock company process that collects messages
    test_pid = self()
    company_pid = spawn_link(fn -> company_process(test_pid, []) end)

    # Generate a unique objective ID for test isolation
    objective_id = "objective_#{:erlang.unique_integer([:positive])}"

    # Start the artifact registry
    artifact_registry = Module.concat(objective_id, ArtifactRegistry)
    {:ok, _} = Registry.start_link(keys: :unique, name: artifact_registry)

    # Start the artifact store
    {:ok, store} =
      ArtifactStore.start_link(
        objective_id: objective_id,
        company_pid: company_pid
      )

    {:ok,
     store: store, company_pid: company_pid, objective_id: objective_id, registry: registry_name}
  end

  describe "artifact storage" do
    test "stores a new artifact", %{store: store} do
      assert {:ok, artifact_id} =
               ArtifactStore.store_artifact(
                 store,
                 "test_artifact",
                 "test content",
                 "text/plain"
               )

      assert {:ok, artifact} = ArtifactStore.get_artifact(store, artifact_id)
      assert artifact.name == "test_artifact"
      assert artifact.content == "test content"
      assert artifact.content_type == "text/plain"
    end

    test "stores artifact with metadata", %{store: store} do
      metadata = %{key: "value"}

      assert {:ok, artifact_id} =
               ArtifactStore.store_artifact(
                 store,
                 "test_artifact",
                 "test content",
                 "text/plain",
                 metadata: metadata
               )

      assert {:ok, artifact} = ArtifactStore.get_artifact(store, artifact_id)
      assert artifact.metadata == metadata
    end

    test "stores artifact with tags", %{store: store} do
      tags = ["tag1", "tag2"]

      assert {:ok, artifact_id} =
               ArtifactStore.store_artifact(
                 store,
                 "test_artifact",
                 "test content",
                 "text/plain",
                 tags: tags
               )

      assert {:ok, artifact} = ArtifactStore.get_artifact(store, artifact_id)
      assert artifact.tags == tags
    end

    test "notifies company of artifact storage", %{store: store, objective_id: objective_id} do
      {:ok, artifact_id} =
        ArtifactStore.store_artifact(
          store,
          "test_artifact",
          "test content",
          "text/plain"
        )

      assert_receive {:artifact_store_update, ^objective_id,
                      {:artifact_stored, %{id: ^artifact_id}}}
    end
  end

  describe "artifact retrieval" do
    setup %{store: store} do
      {:ok, artifact_id} =
        ArtifactStore.store_artifact(
          store,
          "test_artifact",
          "test content",
          "text/plain",
          step_id: "step_1",
          task_id: "task_1",
          tags: ["tag1", "tag2"],
          metadata: %{key: "value"}
        )

      {:ok, artifact_id: artifact_id}
    end

    test "retrieves artifact by ID", %{store: store, artifact_id: artifact_id} do
      assert {:ok, artifact} = ArtifactStore.get_artifact(store, artifact_id)
      assert artifact.id == artifact_id
      assert artifact.name == "test_artifact"
    end

    test "handles non-existent artifact", %{store: store} do
      assert {:error, :not_found} = ArtifactStore.get_artifact(store, "nonexistent")
    end

    test "lists artifacts by step", %{store: store, artifact_id: artifact_id} do
      assert {:ok, artifacts} = ArtifactStore.list_step_artifacts(store, "step_1")
      assert length(artifacts) == 1
      assert hd(artifacts).id == artifact_id
    end

    test "lists all artifacts", %{store: store, artifact_id: artifact_id} do
      assert {:ok, artifacts} = ArtifactStore.list_artifacts(store)
      assert length(artifacts) == 1
      assert hd(artifacts).id == artifact_id
    end

    test "filters artifacts by tags", %{store: store, artifact_id: artifact_id} do
      assert {:ok, artifacts} = ArtifactStore.list_artifacts(store, tags: ["tag1"])
      assert length(artifacts) == 1
      assert hd(artifacts).id == artifact_id

      assert {:ok, artifacts} = ArtifactStore.list_artifacts(store, tags: ["nonexistent"])
      assert artifacts == []
    end

    test "filters artifacts by content type", %{store: store, artifact_id: artifact_id} do
      assert {:ok, artifacts} = ArtifactStore.list_artifacts(store, content_type: "text/plain")
      assert length(artifacts) == 1
      assert hd(artifacts).id == artifact_id

      assert {:ok, artifacts} =
               ArtifactStore.list_artifacts(store, content_type: "application/json")

      assert artifacts == []
    end

    test "filters artifacts by task", %{store: store, artifact_id: artifact_id} do
      assert {:ok, artifacts} = ArtifactStore.list_artifacts(store, created_by: "task_1")
      assert length(artifacts) == 1
      assert hd(artifacts).id == artifact_id

      assert {:ok, artifacts} = ArtifactStore.list_artifacts(store, created_by: "nonexistent")
      assert artifacts == []
    end
  end

  describe "artifact updates" do
    setup %{store: store} do
      {:ok, artifact_id} =
        ArtifactStore.store_artifact(
          store,
          "test_artifact",
          "test content",
          "text/plain",
          metadata: %{initial: "value"}
        )

      {:ok, artifact_id: artifact_id}
    end

    test "updates artifact metadata", %{store: store, artifact_id: artifact_id} do
      assert :ok = ArtifactStore.update_metadata(store, artifact_id, %{new: "value"})
      assert {:ok, artifact} = ArtifactStore.get_artifact(store, artifact_id)
      assert artifact.metadata == %{initial: "value", new: "value"}
    end

    test "adds tags to artifact", %{store: store, artifact_id: artifact_id} do
      assert :ok = ArtifactStore.add_tags(store, artifact_id, ["new_tag"])
      assert {:ok, artifact} = ArtifactStore.get_artifact(store, artifact_id)
      assert "new_tag" in artifact.tags
    end

    test "notifies company of artifact updates", %{
      store: store,
      artifact_id: artifact_id,
      objective_id: objective_id
    } do
      :ok = ArtifactStore.update_metadata(store, artifact_id, %{new: "value"})

      assert_receive {:artifact_store_update, ^objective_id,
                      {:artifact_updated, %{id: ^artifact_id}}}
    end
  end

  # Helper function to simulate company process
  defp company_process(test_pid, messages) do
    receive do
      message ->
        send(test_pid, message)
        company_process(test_pid, [message | messages])
    end
  end
end
