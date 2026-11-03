defmodule Lux.Prisms.Analytics.Defi.DuneQueryPrism do
  @moduledoc """
  Executes or formats a Dune Analytics query and normalizes returned SQL result sets.
  """

  use Lux.Prism,
    name: "Dune Analytics Query",
    description: "Builds query execution requests and parses Dune Analytics SQL results",
    input_schema: %{
      type: :object,
      properties: %{
        query_id: %{type: :integer, description: "Dune SQL query ID"},
        query_parameters: %{type: :object, default: %{}},
        raw_results: %{type: :object, description: "Raw JSON execution results from Dune"}
      },
      required: ["query_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        query_id: %{type: :integer},
        execute_url: %{type: :string},
        state: %{type: :string},
        row_count: %{type: :integer},
        rows: %{type: :array}
      },
      required: ["query_id", "execute_url", "state"]
    }

  alias Lux.Analytics.Defi.Dune

  def handler(input, _ctx) do
    query_id = Map.get(input, :query_id) || Map.get(input, "query_id")
    raw_results = Map.get(input, :raw_results) || Map.get(input, "raw_results")
    exec_url = Dune.execute_query_url(query_id)

    case raw_results do
      nil ->
        {:ok,
         %{
           query_id: query_id,
           execute_url: exec_url,
           state: "prepared_for_execution",
           row_count: 0,
           rows: []
         }}

      data when is_map(data) ->
        case Dune.parse_results(data) do
          {:ok, parsed} ->
            {:ok,
             %{
               query_id: query_id,
               execute_url: exec_url,
               state: to_string(parsed.state),
               row_count: parsed.row_count,
               rows: parsed.rows
             }}

          {:error, err} ->
            {:error, err}
        end
    end
  end
end
