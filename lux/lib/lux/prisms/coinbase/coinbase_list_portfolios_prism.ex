defmodule Lux.Prisms.Coinbase.ListPortfoliosPrism do
  @moduledoc """
  A prism for listing all portfolios on Coinbase Advanced Trade.

  ## Examples

      iex> Lux.Prisms.Coinbase.ListPortfoliosPrism.handler(%{}, %{name: "Agent"})
      {:ok, %{
        portfolios: [%{
          uuid: "abc123",
          name: "Default",
          type: "CONSUMER",
          deleted: false
        }]
      }}
  """

  use Lux.Prism,
    name: "Coinbase List Portfolios",
    description: "Lists all portfolios for the authenticated Coinbase user",
    input_schema: %{
      type: :object,
      properties: %{
        portfolio_type: %{
          type: :string,
          description: "Filter by portfolio type",
          enum: ["UNDEFINED", "DEFAULT", "CONSUMER", "INTX"]
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        portfolios: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              uuid: %{type: :string},
              name: %{type: :string},
              type: %{type: :string},
              deleted: %{type: :boolean}
            }
          }
        }
      },
      required: ["portfolios"]
    }

  alias Lux.Integrations.Coinbase
  require Logger

  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} listing Coinbase portfolios")

    query = case Map.get(params, :portfolio_type) do
      nil -> %{}
      type -> %{portfolio_type: type}
    end

    case Coinbase.get("/api/v3/brokerage/portfolios", query) do
      {:ok, %{"portfolios" => portfolios}} ->
        result = %{
          portfolios: Enum.map(portfolios, fn p ->
            %{uuid: p["uuid"], name: p["name"], type: p["type"], deleted: p["deleted"]}
          end)
        }
        Logger.info("Found #{length(portfolios)} portfolios")
        {:ok, result}

      {:error, {status, body}} ->
        msg = get_in(body, ["message"]) || inspect(body)
        Logger.error("Coinbase list portfolios error: #{status} - #{msg}")
        {:error, {status, msg}}

      {:error, reason} ->
        Logger.error("List portfolios request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
