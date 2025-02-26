defmodule Lux.Integration.AgenticCompany.SetupCompanyTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Beams.AgenticCompany.SetupCompanyBeam
  alias Lux.Config

  # Full-length zero address (40 chars after 0x)
  @zero_address "0x0000000000000000000000000000000000000000"

  setup do
    # Ensure we have the required environment variables
    wallet_address = Config.wallet_address()
    assert is_binary(wallet_address), "WALLET_ADDRESS environment variable not set"
    assert String.starts_with?(wallet_address, "0x"), "WALLET_ADDRESS must start with 0x"
    assert String.length(wallet_address) == 42, "WALLET_ADDRESS must be 42 characters long"

    # Check if we have enough balance for transactions
    case Ethers.get_balance(wallet_address) do
      {:ok, balance} when balance > 0 ->
        :ok

      {:ok, 0} ->
        {:skip, "Test wallet has no balance"}

      {:error, reason} ->
        {:skip, "Failed to get wallet balance: #{inspect(reason)}"}
    end
  end

  describe "company setup" do
    test "successfully creates a company with jobs" do
      input = %{
        company: %{
          # Ensure positive integer
          name: "Test Company #{System.unique_integer([:positive])}",
          agent_token: @zero_address
        },
        jobs: [
          %{name: "Test Job 1"},
          %{name: "Test Job 2"}
        ]
      }

      assert {:ok, result, execution_log} = SetupCompanyBeam.run(input)

      # Verify company was created
      assert is_binary(result.company_address)
      assert String.starts_with?(result.company_address, "0x")
      # 0x + 40 chars
      assert String.length(result.company_address) == 42

      # Verify jobs were created
      assert length(result.jobs) == 2

      for {job, input_job} <- Enum.zip(result.jobs, input.jobs) do
        assert job.name == input_job.name
        assert is_binary(job.job_id)
        assert String.starts_with?(job.job_id, "0x")
      end

      # Verify execution log
      assert execution_log.status == :completed
      assert [create_company, create_jobs, format_output] = execution_log.steps

      assert create_company.id == :create_company
      assert create_company.status == :completed
      assert is_binary(create_company.output.company_address)

      assert create_jobs.id == :create_jobs
      assert create_jobs.status == :completed
      assert length(create_jobs.output.jobs) == 2

      assert format_output.id == :return
      assert format_output.status == :completed
    end

    test "fails with invalid agent token format" do
      input = %{
        company: %{
          name: "Test Company",
          # Invalid Ethereum address format
          agent_token: "0xinvalid"
        },
        jobs: [
          %{name: "Test Job"}
        ]
      }

      assert {:error, _error, execution_log} = SetupCompanyBeam.run(input)
      assert execution_log.status == :failed
      assert [failed_step | _] = execution_log.steps
      assert failed_step.id == :create_company
      assert failed_step.status == :failed
    end

    test "fails with short agent token address" do
      input = %{
        company: %{
          name: "Test Company",
          # Valid hex but wrong length (only 38 chars after 0x)
          agent_token: "0x12345678901234567890123456789012345678"
        },
        jobs: [
          %{name: "Test Job"}
        ]
      }

      assert {:error, _error, execution_log} = SetupCompanyBeam.run(input)
      assert execution_log.status == :failed
      assert [failed_step | _] = execution_log.steps
      assert failed_step.id == :create_company
      assert failed_step.status == :failed
    end

    test "fails with empty job name" do
      input = %{
        company: %{
          name: "Test Company",
          agent_token: @zero_address
        },
        jobs: [
          # Empty job name should fail
          %{name: ""}
        ]
      }

      assert {:error, _error, execution_log} = SetupCompanyBeam.run(input)
      assert execution_log.status == :failed
      assert [_create_company, failed_step | _] = execution_log.steps
      assert failed_step.id == :create_jobs
      assert failed_step.status == :failed
    end
  end
end
