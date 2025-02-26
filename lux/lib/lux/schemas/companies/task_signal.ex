defmodule Lux.Schemas.Companies.TaskSignal do
  @moduledoc """
  Schema for task-related signals exchanged between agents.

  This schema defines the structure for:
  1. Task assignments from CEO to agents
  2. Task status updates from agents to CEO
  3. Task completion reports
  """

  use Lux.SignalSchema,
    name: "company.task",
    version: "1.0.0",
    description: "Represents task assignments and updates between agents",
    schema: %{
      type: :object,
      properties: %{
        type: %{
          type: :string,
          enum: ["assignment", "status_update", "completion", "failure"],
          description: "The type of task signal"
        },
        task_id: %{
          type: :string,
          description: "Unique identifier for the task"
        },
        objective_id: %{
          type: :string,
          description: "ID of the objective this task belongs to"
        },
        title: %{
          type: :string,
          description: "Short description of the task"
        },
        description: %{
          type: :string,
          description: "Detailed description of what needs to be done"
        },
        context: %{
          type: :object,
          description: "Additional context needed for the task",
          properties: %{
            tools: %{
              type: :array,
              items: %{type: :string},
              description: "List of tools that might be needed"
            },
            constraints: %{
              type: :array,
              items: %{type: :string},
              description: "Any constraints or requirements"
            },
            references: %{
              type: :array,
              items: %{type: :string},
              description: "Related resources or references"
            }
          }
        },
        status: %{
          type: :string,
          enum: ["pending", "in_progress", "completed", "failed"],
          description: "Current status of the task"
        },
        progress: %{
          type: :integer,
          minimum: 0,
          maximum: 100,
          description: "Progress percentage (0-100)"
        },
        result: %{
          type: :object,
          properties: %{
            success: %{type: :boolean},
            output: %{type: :string},
            error: %{type: :string},
            artifacts: %{
              type: :array,
              items: %{
                type: :object,
                properties: %{
                  type: %{type: :string},
                  content: %{type: :string}
                }
              }
            }
          }
        },
        metadata: %{
          type: :object,
          description: "Additional metadata about the task",
          properties: %{
            started_at: %{type: :string, format: "date-time"},
            completed_at: %{type: :string, format: "date-time"},
            duration: %{type: :integer},
            attempt: %{type: :integer}
          }
        }
      },
      required: ["type", "task_id", "objective_id", "title", "status"],
      additionalProperties: false
    },
    tags: ["task", "workflow", "agent", "company"],
    compatibility: :full,
    format: :json
end
