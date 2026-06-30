defmodule Lux.Beams.AgenticCompany.SetupCompanyBeam do
  @moduledoc """
  A beam that sets up a new company with initial job openings.

  This beam takes a configuration with company details and initial job openings,
  creates the company using the AgenticCompanyFactory contract, and then
  creates all the specified job openings.

  ## Example Configuration

  ```yaml
  company:
    name: Blockchain Solutions Inc
    agent_token: "0x0000000000000000000000000000000000000000"  # zero address for no token
    ceo_wallet_address: "0x1234..."  # optional, defaults to WALLET_ADDRESS set in the environment variable.
  jobs:
    - name: Senior Smart Contract Developer
    - name: Blockchain Security Analyst
    - name: DeFi Protocol Engineer
  ```

  ## Example Usage

  ```elixir
  # Create a company with three job openings
  {:ok, result, execution_log} = Lux.Beams.AgenticCompany.SetupCompanyBeam.run(%{
    company: %{
      name: "Blockchain Solutions Inc",
      agent_token: "0x0000000000000000000000000000000000000000",
      ceo_wallet_address: "0x1234..."  # optional
    },
    jobs: [
      %{name: "Senior Smart Contract Developer"},
      %{name: "Blockchain Security Analyst"},
      %{name: "DeFi Protocol Engineer"}
    ]
  })

  # The result will look like:
  %{
    company_address: "0x1234...",  # The address of the newly created company
    jobs: [
      %{
        name: "Senior Smart Contract Developer",
        job_id: "0xabcd..."  # The ID of the created job
      },
      %{
        name: "Blockchain Security Analyst",
        job_id: "0xdef0..."
      },
      %{
        name: "DeFi Protocol Engineer",
        job_id: "0x9876..."
      }
    ]
  }

  # The execution_log contains detailed information about each step:
  %{
    beam_id: "b54a67b8-7da6-4e53-a90c-4363c721a2c3",
    started_by: "system",
    started_at: ~U[2024-02-12 06:30:32.034005Z],
    completed_at: ~U[2024-02-12 06:30:32.034607Z],
    status: :completed,
    steps: [
      %{
        id: :create_company,
        status: :completed,
        output: %{company_address: "0x1234..."}
      },
      %{
        id: :create_jobs,
        status: :completed,
        output: %{jobs: [...]}
      },
      %{
        id: :format_output,
        status: :completed,
        output: %{company_address: "0x1234...", jobs: [...]}
      }
    ]
  }
  """

  use Lux.Beam,
    name: "Setup Company",
    description: "Creates a new company and its initial job openings",
    input_schema: %{
      type: :object,
      properties: %{
        company: %{
          type: :object,
          properties: %{
            name: %{type: :string, description: "Name of the company to create"},
            agent_token: %{
              type: :string,
              description: "Address of the agent token to use (zero address if none)"
            },
            ceo_wallet_address: %{
              type: :string,
              description:
                "Optional wallet address to use as company CEO. Defaults to WALLET_ADDRESS set in the environment variable"
            }
          },
          required: ["name", "agent_token"]
        },
        jobs: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              name: %{type: :string, description: "Name of the job opening"}
            },
            required: ["name"]
          }
        }
      },
      required: ["company", "jobs"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        company_address: %{type: :string, description: "Address of the newly created company"},
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
      required: ["company_address", "jobs"]
    },
    generate_execution_log: true

  alias Lux.Prisms.AgenticCompany.CreateCompanyPrism
  alias Lux.Prisms.AgenticCompany.CreateJobsPrism

  sequence do
    # First create the company
    step(:create_company, CreateCompanyPrism, %{
      company_name: [:input, :company, :name],
      agent_token: [:input, :company, :agent_token],
      ceo_wallet_address: [:input, :company, :ceo_wallet_address]
    })

    step(:create_jobs, CreateJobsPrism, %{
      company_address: [:steps, :create_company, :result, :company_address],
      jobs: [:input, :jobs],
      ceo_wallet_address: [:input, :company, :ceo_wallet_address]
    })

    step(:return, Lux.Prisms.NoOp, %{
      company_address: [:steps, :create_company, :result, :company_address],
      jobs: [:steps, :create_jobs, :result, :jobs]
    })
  end
end
