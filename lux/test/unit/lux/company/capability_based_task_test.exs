defmodule Lux.Company.CapabilityBasedTaskTest do
  use ExUnit.Case, async: true

  alias Lux.Agent.Companies.SignalHandler.DefaultImplementation
  alias Lux.Schemas.Companies.TaskSignal
  alias Lux.Signal
  alias Lux.UUID
  alias Test.Support.Companies.CapabilityTeam

  require Logger

  describe "capability-based task assignment" do
    setup do
      # Get the company configuration
      company = CapabilityTeam.view()
      Logger.debug("Company configuration: #{inspect(company)}")

      # Get the researcher role which has research and analysis capabilities
      researcher = Enum.find(company.roles, &(&1.name == "Researcher"))
      Logger.debug("Researcher role: #{inspect(researcher)}")

      # Construct the context with required fields
      context = %{
        agent: researcher.agent,
        role: researcher,
        template_opts: %{
          llm_opts: %{
            model: "test-model",
            temperature: 0.7
          }
        }
      }

      Logger.debug("Test context: #{inspect(context)}")
      %{context: context}
    end

    test "successfully handles task with matching capabilities", %{context: context} do
      signal = %Signal{
        id: UUID.generate(),
        schema_id: TaskSignal,
        payload: %{
          "type" => "assignment",
          "task_id" => UUID.generate(),
          "objective_id" => UUID.generate(),
          "title" => "Research Task",
          "description" => "Conduct research on testing",
          "required_capabilities" => ["research", "analysis"]
        },
        sender: UUID.generate()
      }

      Logger.debug("Test signal: #{inspect(signal)}")
      {:ok, response} = DefaultImplementation.handle_task_assignment(signal, context)
      Logger.debug("Handler response: #{inspect(response)}")

      assert response.schema_id == TaskSignal
      assert response.payload["type"] == "completion"
      assert response.payload["status"] == "completed"
      assert response.payload["result"]["success"] == true
      assert response.metadata["agent_capabilities"] == context.role.capabilities
    end

    test "rejects task when capabilities don't match", %{context: context} do
      signal = %Signal{
        id: UUID.generate(),
        schema_id: TaskSignal,
        payload: %{
          "type" => "assignment",
          "task_id" => UUID.generate(),
          "objective_id" => UUID.generate(),
          "title" => "Design Task",
          "description" => "Create UI mockups",
          "required_capabilities" => ["design", "ui"]
        },
        sender: UUID.generate()
      }

      Logger.debug("Test signal: #{inspect(signal)}")
      {:ok, response} = DefaultImplementation.handle_task_assignment(signal, context)
      Logger.debug("Handler response: #{inspect(response)}")

      assert response.schema_id == TaskSignal
      assert response.payload["type"] == "failure"
      assert response.payload["status"] == "failed"
      assert response.payload["result"]["success"] == false
      assert response.payload["result"]["error"] == "Agent lacks required capabilities"
      assert response.payload["result"]["required_capabilities"] == ["design", "ui"]
      assert response.payload["result"]["agent_capabilities"] == context.role.capabilities
    end

    test "handles empty required capabilities list", %{context: context} do
      signal = %Signal{
        id: UUID.generate(),
        schema_id: TaskSignal,
        payload: %{
          "type" => "assignment",
          "task_id" => UUID.generate(),
          "objective_id" => UUID.generate(),
          "title" => "Simple Task",
          "description" => "Basic task with no special requirements",
          "required_capabilities" => []
        },
        sender: UUID.generate()
      }

      Logger.debug("Test signal: #{inspect(signal)}")
      {:ok, response} = DefaultImplementation.handle_task_assignment(signal, context)
      Logger.debug("Handler response: #{inspect(response)}")

      assert response.schema_id == TaskSignal
      assert response.payload["type"] == "completion"
      assert response.payload["status"] == "completed"
      assert response.payload["result"]["success"] == true
    end

    test "includes used capabilities in successful response", %{context: context} do
      signal = %Signal{
        id: UUID.generate(),
        schema_id: TaskSignal,
        payload: %{
          "type" => "assignment",
          "task_id" => UUID.generate(),
          "objective_id" => UUID.generate(),
          "title" => "Analysis Task",
          "description" => "Analyze research data",
          "required_capabilities" => ["analysis"]
        },
        sender: UUID.generate()
      }

      {:ok, response} = DefaultImplementation.handle_task_assignment(signal, context)

      assert response.schema_id == TaskSignal
      assert response.payload["type"] == "completion"
      assert response.payload["result"]["used_capabilities"] == ["analysis"]
    end
  end
end
