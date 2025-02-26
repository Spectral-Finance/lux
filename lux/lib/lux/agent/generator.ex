defmodule Lux.Agent.Generator do
  @moduledoc """
  Generates Elixir agent modules from Config structs.
  """

  alias Lux.Agent.Config

  @doc """
  Generates an Elixir module from a Config struct.
  """
  @spec generate(Config.t()) :: {:ok, module()} | {:error, term()}
  def generate(%Config{} = config) do
    with {:ok, module_name} <- validate_module_name(config.module) do
      quoted =
        quote do
          use Lux.Agent,
            id: unquote(config.id),
            name: unquote(config.name),
            description: unquote(config.description),
            goal: unquote(config.goal),
            template: unquote(config.template),
            template_opts:
              Lux.Agent.Generator.atomize_keys(unquote(Macro.escape(config.template_opts))),
            prisms:
              Enum.map(
                unquote(Macro.escape(config.prisms)),
                &Lux.Agent.Generator.validate_module_name!/1
              ),
            beams:
              Enum.map(
                unquote(Macro.escape(config.beams)),
                &Lux.Agent.Generator.validate_module_name!/1
              ),
            lenses:
              Enum.map(
                unquote(Macro.escape(config.lenses)),
                &Lux.Agent.Generator.validate_module_name!/1
              ),
            signal_handlers: unquote(Macro.escape(config.signal_handlers)),
            llm_config: Lux.Agent.Generator.atomize_keys(unquote(Macro.escape(config.llm_config)))
        end

      Module.create(module_name, quoted, Macro.Env.location(__ENV__))
      {:ok, module_name}
    end
  end

  def validate_module_name!(name) do
    case validate_module_name(name) do
      {:ok, module_name} -> module_name
      {:error, error} -> raise error
    end
  end

  def validate_module_name(nil), do: {:error, :missing_module_name}

  def validate_module_name(name) when is_binary(name) do
    if String.starts_with?(name, "Elixir.") do
      {:ok, String.to_atom(name)}
    else
      {:ok, String.to_atom("Elixir." <> name)}
    end
  end

  def validate_module_name(name) when is_atom(name), do: {:ok, name}
  def validate_module_name(_), do: {:error, :invalid_module_name}

  def atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) ->
        {String.to_atom(key), atomize_keys(value)}

      {key, value} ->
        {key, atomize_keys(value)}
    end)
  end

  def atomize_keys(list) when is_list(list) do
    Enum.map(list, &atomize_keys/1)
  end

  def atomize_keys(other), do: other
end
