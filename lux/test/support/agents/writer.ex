defmodule Test.Support.Agents.Writer do
  @moduledoc """
  Writer agent implementation for testing.
  Handles content creation and editing.
  """
  use Lux.Agent,
    template: :company_agent,
    signal_handlers: [
      {Lux.Schemas.TaskSignal, {__MODULE__, :task_handler}}
    ],
    llm_config: %{
      # Higher temperature for more creative writing
      temperature: 0.7,
      messages: [
        %{
          role: "system",
          content: """
          You are a Content Writer responsible for creating engaging blog content.
          Your tasks include:
          1. Creating detailed outlines
          2. Writing first drafts
          3. Editing and refining content
          4. Ensuring proper structure and flow
          """
        }
      ]
    }

  def task_handler(%{schema_id: Lux.Schemas.TaskSignal} = signal, context) do
    case signal.payload do
      %{"type" => "assignment", "task" => "create_outline"} ->
        # Create outline using LLM
        {:ok, outline} = create_outline(signal.payload["research"], context)
        {:ok, create_response(signal, outline)}

      %{"type" => "assignment", "task" => "write_draft"} ->
        # Write draft using LLM
        {:ok, draft} = write_draft(signal.payload["outline"], context)
        {:ok, create_response(signal, draft)}

      %{"type" => "assignment", "task" => "edit_content"} ->
        # Edit content using LLM
        {:ok, edited} = edit_content(signal.payload["content"], context)
        {:ok, create_response(signal, edited)}

      _ ->
        {:error, :unknown_task}
    end
  end

  defp create_outline(research, agent_context) do
    prompt = """
    Create a detailed outline based on this research:
    #{inspect(research)}

    Include:
    1. Introduction section
    2. Main sections with key points
    3. Supporting subsections
    4. Conclusion section

    Respond with a JSON object containing:
    {
      "title": "proposed title",
      "sections": [
        {
          "title": "section title",
          "points": ["list", "of", "points"],
          "subsections": [
            {
              "title": "subsection title",
              "points": ["list", "of", "points"]
            }
          ]
        }
      ]
    }
    """

    case Lux.Agent.Base.evaluate(prompt, agent_context) do
      {:ok, response} -> {:ok, Jason.decode!(response)}
      error -> error
    end
  end

  defp write_draft(outline, agent_context) do
    prompt = """
    Write a blog post draft following this outline:
    #{inspect(outline)}

    Ensure:
    1. Engaging introduction
    2. Clear flow between sections
    3. Supporting evidence for claims
    4. Strong conclusion
    5. Appropriate tone and style

    Respond with a JSON object containing:
    {
      "title": "final title",
      "content": "full blog post content",
      "metadata": {
        "word_count": number,
        "reading_time": "estimated reading time",
        "target_audience": "intended audience"
      }
    }
    """

    case Lux.Agent.Base.evaluate(prompt, agent_context) do
      {:ok, response} -> {:ok, Jason.decode!(response)}
      error -> error
    end
  end

  defp edit_content(content, agent_context) do
    prompt = """
    Edit and improve this content:
    #{inspect(content)}

    Focus on:
    1. Clarity and conciseness
    2. Grammar and style
    3. Flow and transitions
    4. Technical accuracy
    5. Engagement factor

    Respond with a JSON object containing:
    {
      "edited_content": "improved content",
      "changes_made": ["list", "of", "changes"],
      "improvement_metrics": {
        "clarity": "score 1-10",
        "engagement": "score 1-10",
        "technical_accuracy": "score 1-10"
      }
    }
    """

    case Lux.Agent.Base.evaluate(prompt, agent_context) do
      {:ok, response} -> {:ok, Jason.decode!(response)}
      error -> error
    end
  end

  defp create_response(original_signal, result) do
    %Lux.Signal{
      id: Lux.UUID.generate(),
      schema_id: original_signal.schema_id,
      payload:
        Map.merge(result, %{
          "type" => "completion",
          "task_id" => original_signal.payload["task_id"],
          "objective_id" => original_signal.payload["objective_id"]
        }),
      recipient: original_signal.sender
    }
  end

  @impl true
  def handle_task_assignment(signal, _context) do
    # Handle task assignment
    {:ok, signal}
  end

  @impl true
  def handle_task_update(signal, _context) do
    # Handle task update
    {:ok, signal}
  end

  @impl true
  def handle_task_completion(signal, _context) do
    # Handle task completion
    {:ok, signal}
  end

  @impl true
  def handle_task_failure(signal, _context) do
    # Handle task failure
    {:ok, signal}
  end

  @impl true
  def handle_objective_evaluation(signal, _context) do
    # Handle objective evaluation
    {:ok, signal}
  end

  @impl true
  def handle_objective_next_step(signal, _context) do
    # Handle objective next step
    {:ok, signal}
  end

  @impl true
  def handle_objective_update(signal, _context) do
    # Handle objective update
    {:ok, signal}
  end

  @impl true
  def handle_objective_completion(signal, _context) do
    # Handle objective completion
    {:ok, signal}
  end
end
