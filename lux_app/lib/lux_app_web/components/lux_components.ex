defmodule LuxAppWeb.LuxComponents do
  use Phoenix.Component

  import Phoenix.HTML.Form

  @llm_providers [
    OpenAI: "openai",
    Anthropic: "anthropic"
  ]

  @llm_models %{
    "openai" => [
      "GPT-4o-mini": "gpt-4o-mini",
      "GPT-4o": "gpt-4o",
      "GPT-4": "gpt-4"
    ],
    "anthropic" => [
      "Claude 3.7 Sonnet": "claude-3.7-sonnet",
      "Claude 3.5 Sonnet": "claude-3-5-sonnet",
      "Claude 3 Haiku": "claude-3-haiku"
    ]
  }

  attr :llm_providers, :map, default: @llm_providers
  attr :selected, :map, default: nil

  def llm_provider_selector(assigns) do
    ~H"""
    {options_for_select(@llm_providers, @selected)}
    """
  end

  attr :llm_models, :map, default: @llm_models
  attr :selected_provider, :string, default: nil
  attr :selected, :string, default: nil

  def llm_model_selector(assigns) do
    ~H"""
    {options_for_select(@llm_models[@selected_provider], @selected)}
    """
  end

  @node_types %{
    "agent" => %{
      label: "Agent",
      description: "An autonomous agent that can perform tasks"
    },
    "prism" => %{
      label: "Prism",
      description: "Processes and transforms data"
    },
    "lens" => %{
      label: "Lens",
      description: "Retrieves data from external sources"
    },
    "beam" => %{
      label: "Beam",
      description: "Executes actions in external systems"
    }
  }

  attr :node_types, :map, default: @node_types

  def palette(assigns) do
    ~H"""
    <div class="w-64 border-r border-gray-700 p-4 overflow-y-auto">
      <h2 class="text-xl font-bold mb-4">Components</h2>
      <div class="space-y-2">
        <%= for {type, info} <- @node_types do %>
          <div
            class="p-3 bg-gray-800 rounded-md cursor-move border border-gray-700 hover:border-blue-500 transition-colors"
            draggable="true"
            phx-hook="DraggableNode"
            id={"draggable-#{type}"}
            data-type={type}
          >
            <div class="flex items-center">
              <div
                class="w-8 h-8 rounded-full mr-2 flex items-center justify-center"
                style={"background: #{color(type)}20"}
              >
                <div class="w-5 h-5" style={"background: #{color(type)}"}></div>
              </div>
              <div>
                <div class="font-medium">{info.label}</div>
                <div class="text-xs text-gray-400">{info.description}</div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def color("agent"), do: "#4ade80"
  def color("prism"), do: "#60a5fa"
  def color("lens"), do: "#c084fc"
  def color("beam"), do: "#fb923c"

  def initial_data("agent"),
    do: %{
      "label" => "New Agent",
      "description" => "Agent Description",
      "goal" => "Agent Goal",
      "components" => [],
      "llm_config" => %{
        "provider" => "openai",
        "model" => "gpt-4o-mini",
        "temperature" => 0.5
      }
    }

  def initial_data("prism"),
    do: %{
      "label" => "New Prism",
      "description" => "Prism description",
      "input_schema" => nil,
      "output_schema" => nil
    }

  def initial_data("lens"),
    do: %{
      "label" => "New Lens",
      "description" => "Lens description",
      "url" => "",
      "method" => "GET",
      "schema" => nil
    }

  def initial_data("beam"),
    do: %{
      "label" => "New Beam",
      "description" => "Beam description",
      "url" => "",
      "method" => "GET",
      "schema" => nil
    }
end
