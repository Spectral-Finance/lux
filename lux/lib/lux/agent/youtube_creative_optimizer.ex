defmodule Lux.Agent.YouTubeCreativeOptimizer do
  @moduledoc """
  An agent focused on generating high-conversion metadata (titles, descriptions, tags).
  """
  use Lux.Agent

  def setup do
    %{
      name: "YouTube Creative Optimizer",
      description: "Generates SEO-optimized titles, descriptions, and tags using LLMs.",
      goal: "Maximize CTR and search visibility through optimized metadata.",
      module: __MODULE__,
      capabilities: [:content_generation, :seo_optimization]
    }
  end

  def generate_metadata(agent, %{topic: topic, keywords: keywords}) do
    prompt = """
    Act as a YouTube SEO expert. Generate 3 viral titles, a 200-word description including keywords, 
    and 15 optimized tags for a video about: #{topic}. 
    Keywords to include: #{Enum.join(keywords, ", ")}.
    Format as JSON.
    """
    
    # Uses Lux's built-in LLM integration
    Lux.LLM.chat(agent, prompt)
  end
end
