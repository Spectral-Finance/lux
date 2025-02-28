defmodule LuxApp.Contexts.EdgesTest do
  use LuxApp.DataCase

  alias LuxApp.Contexts.Edges
  alias LuxApp.Schemas.Edge
  alias LuxApp.Contexts.Agents
  alias LuxApp.Contexts.Prisms

  describe "edges" do
    @valid_attrs %{
      source_type: "agent",
      target_type: "prism",
      source_port: "output",
      target_port: "input",
      label: "Test Edge",
      metadata: %{weight: 1.0}
    }
    @update_attrs %{
      label: "Updated Edge",
      metadata: %{weight: 2.0}
    }
    @invalid_attrs %{source_id: nil, target_id: nil}

    def create_source_and_target do
      {:ok, agent} = Agents.create_agent(%{name: "Source Agent"})
      {:ok, prism} = Prisms.create_prism(%{name: "Target Prism"})
      {agent, prism}
    end

    def edge_fixture(attrs \\ %{}) do
      {agent, prism} = create_source_and_target()

      {:ok, edge} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Enum.into(%{source_id: agent.id, target_id: prism.id})
        |> Edges.create_edge()

      edge
    end

    test "list_edges/1 returns all edges with pagination" do
      edge = edge_fixture()
      {:ok, {edges, _meta}} = Edges.list_edges(%{})
      assert Enum.map(edges, & &1.id) == [edge.id]
    end

    test "list_edges/1 with filtering" do
      edge1 = edge_fixture(%{label: "Edge One"})
      _edge2 = edge_fixture(%{label: "Edge Two"})

      # Filter by label
      {:ok, {edges, _meta}} =
        Edges.list_edges(%{
          filters: [%{field: :label, op: :ilike_and, value: "One"}]
        })

      assert length(edges) == 1
      assert hd(edges).id == edge1.id
    end

    test "list_edges_by_source/3 returns edges for a specific source" do
      edge = edge_fixture()
      {:ok, {edges, _meta}} = Edges.list_edges_by_source(edge.source_id, edge.source_type, %{})
      assert Enum.map(edges, & &1.id) == [edge.id]
    end

    test "list_edges_by_target/3 returns edges for a specific target" do
      edge = edge_fixture()
      {:ok, {edges, _meta}} = Edges.list_edges_by_target(edge.target_id, edge.target_type, %{})
      assert Enum.map(edges, & &1.id) == [edge.id]
    end

    test "get_edge!/1 returns the edge with given id" do
      edge = edge_fixture()
      fetched_edge = Edges.get_edge!(edge.id)

      # Compare all fields except metadata which may have string keys
      assert fetched_edge.id == edge.id
      assert fetched_edge.source_id == edge.source_id
      assert fetched_edge.source_type == edge.source_type
      assert fetched_edge.source_port == edge.source_port
      assert fetched_edge.target_id == edge.target_id
      assert fetched_edge.target_type == edge.target_type
      assert fetched_edge.target_port == edge.target_port
      assert fetched_edge.label == edge.label

      # Check that metadata has the same content regardless of key type
      assert Map.get(fetched_edge.metadata, "weight") == 1.0 ||
               Map.get(fetched_edge.metadata, :weight) == 1.0
    end

    test "create_edge/1 with valid data creates a edge" do
      {agent, prism} = create_source_and_target()

      attrs =
        @valid_attrs
        |> Enum.into(%{source_id: agent.id, target_id: prism.id})

      assert {:ok, %Edge{} = edge} = Edges.create_edge(attrs)
      assert edge.source_id == agent.id
      assert edge.target_id == prism.id
      assert edge.label == "Test Edge"
    end

    test "create_edge/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Edges.create_edge(@invalid_attrs)
    end

    test "update_edge/2 with valid data updates the edge" do
      edge = edge_fixture()
      assert {:ok, %Edge{} = edge} = Edges.update_edge(edge, @update_attrs)
      assert edge.label == "Updated Edge"

      # Check metadata value regardless of key type
      assert Map.get(edge.metadata, "weight") == 2.0 || Map.get(edge.metadata, :weight) == 2.0
    end

    test "update_edge/2 with invalid data returns error changeset" do
      edge = edge_fixture()
      assert {:error, %Ecto.Changeset{}} = Edges.update_edge(edge, @invalid_attrs)

      fetched_edge = Edges.get_edge!(edge.id)

      # Compare all fields except metadata which may have string keys
      assert fetched_edge.id == edge.id
      assert fetched_edge.source_id == edge.source_id
      assert fetched_edge.source_type == edge.source_type
      assert fetched_edge.source_port == edge.source_port
      assert fetched_edge.target_id == edge.target_id
      assert fetched_edge.target_type == edge.target_type
      assert fetched_edge.target_port == edge.target_port
      assert fetched_edge.label == edge.label
    end

    test "delete_edge/1 deletes the edge" do
      edge = edge_fixture()
      assert {:ok, %Edge{}} = Edges.delete_edge(edge)
      assert_raise Ecto.NoResultsError, fn -> Edges.get_edge!(edge.id) end
    end

    test "change_edge/1 returns a edge changeset" do
      edge = edge_fixture()
      assert %Ecto.Changeset{} = Edges.change_edge(edge)
    end
  end
end
