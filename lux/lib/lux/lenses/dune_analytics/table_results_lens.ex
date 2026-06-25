defmodule Lux.Lenses.DuneAnalytics.TableResults do
  @moduledoc """
  Lens for fetching latest results from a Dune Analytics materialized table.

  ## Examples

  ```elixir
  # Get latest results from ethereum trades table
  Lux.Lenses.DuneAnalytics.TableResults.focus(%{
    dataset: "ethereum",
    table: "trades"
  })
  ```
  """

  alias Lux.Integrations.DuneAnalytics

  use Lux.Lens,
    name: "DuneAnalytics.TableResults",
    description: "Fetches the latest results from a Dune Analytics materialized table",
    url: "https://api.dune.com/api/v3/table/:dataset/:table/results/latest",
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
          description: "Dataset name (e.g., 'ethereum', 'binance')"
        },
        table: %{
          type: :string,
          description: "Table name (e.g., 'trades', 'tokens')"
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
      dataset: Map.get(body, "dataset"),
      table: Map.get(body, "table"),
      result: Map.get(body, "result", %{}),
      metadata: Map.get(body, "metadata", %{}),
      timestamp: DateTime.utc_now()
    }}
  end

  def after_focus(body) do
    {:ok, %{raw: body, timestamp: DateTime.utc_now()}}
  end
end
