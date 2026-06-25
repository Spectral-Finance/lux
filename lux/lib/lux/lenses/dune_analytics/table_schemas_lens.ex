defmodule Lux.Lenses.DuneAnalytics.TableSchemas do
  @moduledoc """
  Lens for fetching schema information for a Dune Analytics materialized table.

  ## Examples

  ```elixir
  # Get schema for ethereum trades table
  Lux.Lenses.DuneAnalytics.TableSchemas.focus(%{
    dataset: "ethereum",
    table: "trades"
  })
  ```
  """

  alias Lux.Integrations.DuneAnalytics

  use Lux.Lens,
    name: "DuneAnalytics.TableSchemas",
    description: "Fetches column schema definitions for a Dune Analytics table",
    url: "https://api.dune.com/api/v3/table/:dataset/:table/schemas",
    method: :get,
    headers: [{"Content-Type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &__MODULE__.authenticate/1
    },
    schema: %{
      type: :object,
      properties: %{
        dataset: %{
          type: :string,
          description: "Dataset name (e.g., 'ethereum')"
        },
        table: %{
          type: :string,
          description: "Table name (e.g., 'trades')"
        }
      },
      required: ["dataset", "table"]
    }

  def before_focus(params) do
    dataset = Map.get(params, :dataset, "")
    table = Map.get(params, :table, "")
    params
    |> Map.put(:dataset, URI.encode(dataset))
    |> Map.put(:table, URI.encode(table))
  end

  def authenticate(lens) do
    headers = lens.headers ++ DuneAnalytics.headers()
    %{lens | headers: headers}
  end

  def after_focus(body) when is_map(body) do
    {:ok, %{
      columns: Map.get(body, "columns", []),
      dataset: Map.get(body, "dataset"),
      table: Map.get(body, "table"),
      timestamp: DateTime.utc_now()
    }}
  end

  def after_focus(body) do
    {:ok, %{raw: body, timestamp: DateTime.utc_now()}}
  end
end
