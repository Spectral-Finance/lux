defmodule Lux.Agent.Companies.DefaultImplementationTest do
  use UnitCase, async: true

  alias Lux.Agent.Companies.SignalHandler.DefaultImplementation
  alias Lux.AgentHub
  alias Lux.Schemas.Companies.ObjectiveSignal
  alias Lux.Schemas.Companies.TaskSignal
  alias Lux.Signal

  describe "signal routing" do
    setup do
      context = %{
        beams: [],
        lenses: [],
        prisms: []
      }

      task_signal = %Signal{
        id: "test-1",
        schema_id: TaskSignal,
        payload: %{
          "type" => "assignment",
          "task_id" => "task-1",
          "objective_id" => "obj-1",
          "title" => "Test Task",
          "description" => "A test task",
          "status" => "pending"
        },
        sender: "test-sender"
      }

      %{context: context, task_signal: task_signal}
    end

    test "handles task update signal", %{context: context, task_signal: signal} do
      signal = %{signal | payload: Map.put(signal.payload, "type", "status_update")}
      assert {:ok, response} = DefaultImplementation.handle_task_update(signal, context)
      assert response.schema_id == TaskSignal
      assert response.payload["type"] == "status_update"
      assert response.payload["status"] == "in_progress"
      assert response.recipient == signal.sender
    end

    test "handles unknown signal type", %{context: context, task_signal: signal} do
      signal = %{signal | payload: Map.put(signal.payload, "type", "unknown")}

      assert {:error, :unsupported_task_type} =
               DefaultImplementation.handle_signal(signal, context)
    end

    test "handles unknown schema", %{context: context, task_signal: signal} do
      signal = %{signal | schema_id: "unknown"}
      assert {:error, :unsupported_schema} = DefaultImplementation.handle_signal(signal, context)
    end
  end

  describe "objective signal handling" do
    setup do
      # Start a real AgentHub for testing
      hub_name = :"agent_hub_#{:erlang.unique_integer([:positive])}"
      start_supervised!({AgentHub, name: hub_name})

      # Create a test agent with capabilities
      test_agent = %{
        id: "agent-1",
        name: "Test Agent",
        capabilities: ["research", "analysis"]
      }

      # Register the test agent with the hub
      :ok = AgentHub.register(hub_name, test_agent, self(), test_agent.capabilities)

      context = %{
        beams: [],
        lenses: [],
        prisms: [],
        hub: hub_name
      }

      objective_signal = %Signal{
        id: "test-2",
        schema_id: ObjectiveSignal,
        sender: "test-sender",
        payload: %{
          "objective_id" => "obj-1",
          "title" => "Test Objective",
          "type" => "evaluate",
          "steps" => [
            %{
              "index" => 0,
              "description" => "First step",
              "status" => "pending",
              "required_capabilities" => ["research"]
            }
          ]
        }
      }

      %{context: context, objective_signal: objective_signal}
    end

    test "handles objective evaluation signal", %{context: context, objective_signal: signal} do
      {:ok, response} = DefaultImplementation.handle_objective_evaluation(signal, context)

      assert response.schema_id == ObjectiveSignal
      assert response.payload["type"] == "evaluate"
      assert response.payload["evaluation"]["decision"] == "continue"
      assert response.payload["evaluation"]["assigned_agent"] == "agent-1"
      assert response.payload["evaluation"]["required_capabilities"] == ["research"]
    end

    test "handles objective update signal", %{context: context, objective_signal: signal} do
      signal = %{
        signal
        | payload:
            Map.merge(signal.payload, %{
              "type" => "status_update",
              "context" => %{
                "progress" => 50
              }
            })
      }

      assert {:ok, _} =
               DefaultImplementation.handle_objective_update(signal, context)
    end

    test "handles objective completion signal", %{context: context, objective_signal: signal} do
      signal = %{
        signal
        | payload:
            Map.merge(signal.payload, %{
              "type" => "completion",
              "context" => %{
                "progress" => 100
              },
              "steps" => [
                %{
                  "index" => 0,
                  "description" => "First step",
                  "status" => "completed"
                }
              ]
            })
      }

      assert {:ok, _} =
               DefaultImplementation.handle_objective_completion(signal, context)
    end
  end
end
