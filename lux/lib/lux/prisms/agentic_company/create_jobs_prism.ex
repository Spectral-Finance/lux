defmodule Lux.Prisms.AgenticCompany.CreateJobsPrism do
  @moduledoc """
  A prism that creates multiple jobs in a company in parallel.

  This prism takes a list of job configurations and creates them all in the specified company.
  If any job creation fails, the entire operation is considered failed.
  """

  use Lux.Prism,
    name: "Create Multiple Jobs",
    description: "Creates multiple jobs in a company",
    input_schema: %{
      type: :object,
      properties: %{
        company_address: %{
          type: :string,
          description: "Address of the company contract"
        },
        jobs: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              name: %{type: :string, description: "Name of the job opening"}
            },
            required: [:name]
          }
        },
        ceo_wallet_address: %{
          type: :string,
          description:
            "Optional wallet address to use as company CEO. Defaults to WALLET_ADDRESS set in the environment variable."
        }
      },
      required: [:company_address, :jobs]
    },
    output_schema: %{
      type: :object,
      properties: %{
        jobs: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              name: %{type: :string},
              job_id: %{type: :string}
            }
          }
        }
      },
      required: [:jobs]
    }

  alias Lux.Prisms.AgenticCompany.CreateJobPrism

  def handler(%{company_address: company_address, jobs: jobs} = input, _ctx) do
    # Get the CEO wallet address from input, but let CreateJobPrism handle the default
    ceo_wallet =
      case Map.get(input, :ceo_wallet_address) do
        nil -> nil
        "" -> nil
        wallet -> wallet
      end

    results =
      Enum.map(jobs, fn job ->
        case CreateJobPrism.run(%{
               company_address: company_address,
               job_name: job.name,
               ceo_wallet_address: ceo_wallet
             }) do
          {:ok, result} -> Map.put(job, :job_id, result.job_id)
          {:error, reason} -> {:error, reason}
        end
      end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> {:ok, %{jobs: Enum.filter(results, &is_map/1)}}
      {:error, reason} -> {:error, reason}
    end
  end
end
