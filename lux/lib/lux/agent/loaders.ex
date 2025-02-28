defmodule Lux.Agent.Loaders do
  @moduledoc """
  Entry point for loading agent configurations from various sources.
  """

  alias Lux.Agent.Generator
  alias Lux.Agent.Loaders.Json, as: JsonLoader

  require Logger

  @doc """
  Creates agent module(s) from JSON configuration(s).
  The source can be:
  - A JSON string: `~s({"id": "researcher", ...})`
  - A file path: `"agents/researcher.json"`
  - A directory path: `"agents/"` (loads all .json files)
  - A list of file paths: `["agents/researcher.json", "agents/writer.json"]`

  Returns:
  - `{:ok, [module()]}` for successful loads (always returns a list)
  - `{:error, term()}` on failure

  ## Examples

      # Load from file
      {:ok, [ResearchAgent]} = Loaders.from_json("agents/researcher.json")

      # Load from directory
      {:ok, [ResearchAgent, WriterAgent]} = Loaders.from_json("agents/")

      # Load from JSON string
      json = ~s({
        "id": "researcher",
        "name": "Research Agent",
        "description": "Conducts research",
        "goal": "Research effectively",
        "module": "ResearchAgent"
      })
      {:ok, [ResearchAgent]} = Loaders.from_json(json)

      # Load multiple files
      {:ok, [Agent1, Agent2]} = Loaders.from_json(["agent1.json", "agent2.json"])
  """
  @spec from_json(String.t() | [String.t()]) :: {:ok, [module()]} | {:error, term()}
  def from_json(source) when is_binary(source) or is_list(source) do
    with {:ok, configs} <- JsonLoader.load(source) do
      results = Enum.map(configs, &Generator.generate/1)

      case Enum.split_with(results, &match?({:ok, _}, &1)) do
        {[], _errors} -> {:error, :no_valid_modules_generated}
        {valid, _errors} -> {:ok, Enum.map(valid, fn {:ok, mod} -> mod end)}
      end
    end
  end
end
