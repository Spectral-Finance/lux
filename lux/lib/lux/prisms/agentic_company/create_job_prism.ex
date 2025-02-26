defmodule Lux.Prisms.AgenticCompany.CreateJobPrism do
  @moduledoc """
  A prism that creates a new job in an existing AgenticCompany contract.

  ## Example

      iex> Lux.Prisms.AgenticCompany.CreateJobPrism.run(%{
      ...>   company_address: "0xdf610daa6acc8c7ca4b68dfd2a7bed96bafeee34",
      ...>   job_name: "Content Writer",
      ...>   ceo_wallet_address: "0x1234..."  # optional, defaults to WALLET_ADDRESS set in the environment variable
      ...> })
      {:ok, %{
        job_id: "0xabcd..."  # The ID of the newly created job
      }}
  """

  use Lux.Prism,
    name: "Create Job",
    description: "Creates a new job in an existing AgenticCompany contract",
    input_schema: %{
      type: :object,
      properties: %{
        company_address: %{
          type: :string,
          description: "Address of the AgenticCompany contract"
        },
        job_name: %{
          type: :string,
          description: "Name of the job to create"
        },
        ceo_wallet_address: %{
          type: :string,
          description:
            "Optional wallet address to use as company CEO. Defaults to WALLET_ADDRESS set in the environment variable."
        }
      },
      required: ["company_address", "job_name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        job_id: %{
          type: :string,
          description: "ID of the newly created job"
        }
      },
      required: ["job_id"]
    }

  alias Lux.Config
  alias Lux.Web3.Contracts.AgenticCompany

  require Logger

  def handler(%{company_address: company_address, job_name: job_name} = input, _ctx) do
    # Get the CEO wallet address from input or default to Config.wallet_address()
    ceo_wallet =
      case Map.get(input, :ceo_wallet_address) do
        nil -> Config.wallet_address()
        "" -> Config.wallet_address()
        wallet -> wallet
      end

    Logger.info(
      "Creating job '#{job_name}' in company at #{company_address} as CEO #{ceo_wallet}"
    )

    with {:ok, tx_hash} <- create_job_transaction(company_address, job_name, ceo_wallet),
         Logger.info("Job creation transaction sent with hash: #{tx_hash}"),
         task = Task.async(fn -> wait_for_job_created_event(company_address, tx_hash) end),
         {:ok, job_id} <- Task.await(task, :timer.minutes(5)) do
      {:ok, %{job_id: job_id}}
    else
      {:error, reason} ->
        Logger.error("Job creation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp create_job_transaction(company_address, job_name, ceo_wallet) do
    job_name
    |> AgenticCompany.create_job()
    |> Ethers.send_transaction(from: ceo_wallet, to: company_address)
  end

  defp wait_for_job_created_event(company_address, tx_hash) do
    Logger.debug("Waiting for job creation event from transaction #{tx_hash}")

    case Ethers.get_transaction_receipt(tx_hash) do
      {:ok, receipt} ->
        Logger.debug("Received receipt for transaction #{tx_hash}")
        process_receipt(company_address, receipt, tx_hash)

      {:error, :transaction_receipt_not_found} ->
        Process.sleep(2000)
        wait_for_job_created_event(company_address, tx_hash)

      {:error, reason} ->
        Logger.error("Failed to get receipt for transaction #{tx_hash}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp process_receipt(company_address, receipt, tx_hash) do
    event_filter = AgenticCompany.EventFilters.job_created(nil)

    receipt["logs"]
    |> Enum.find(&matching_event?(&1, event_filter))
    |> handle_event_log(company_address, tx_hash)
  end

  defp matching_event?(log, event_filter) do
    List.first(log["topics"]) == List.first(event_filter.topics)
  end

  defp handle_event_log(nil, company_address, tx_hash) do
    Process.sleep(2000)
    wait_for_job_created_event(company_address, tx_hash)
  end

  defp handle_event_log(log, _company_address, _tx_hash) do
    job_id = Enum.at(log["topics"], 1)
    Logger.info("Found job ID in event: #{job_id}")
    {:ok, job_id}
  end
end
