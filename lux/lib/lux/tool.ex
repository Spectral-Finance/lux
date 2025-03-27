  defmodule Lux.MCP.Tool do
    @moduledoc """
    A struct to represent a tool in the MCP (Model Context Protocol).
    """
    @type t :: %__MODULE__{
            name: String.t(),
            description: String.t(),
            input_schema: map()
          }

    defstruct [:name, :description, :input_schema]

    def new(name, description, input_schema) do
      %__MODULE__{
        name: name,
        description: description,
        input_schema: input_schema
      }
    end

    def from_map(%{"name" => name, "description" => description, "inputSchema" => input_schema}) do
      new(name, description, input_schema)
    end

    def to_map(%__MODULE__{name: name, description: description, input_schema: input_schema}) do
      %{"name" => name, "description" => description, "inputSchema" => input_schema}
    end
  end
