defmodule Lux.Lenses.Etherscan.TxStatus do
  @moduledoc """
  Lens for checking the execution status of a contract from the Etherscan API.

  ## Examples

  ```elixir
  # Check contract execution status (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.TxStatus.focus(%{
    txhash: "0x15f8e5ea1079d9a0bb04a4c58ae5fe7654b5b2b4463375ff7ffb490aa0032f3a"
  })

  # Check contract execution status on a specific chain
  Lux.Lenses.Etherscan.TxStatus.focus(%{
    txhash: "0x15f8e5ea1079d9a0bb04a4c58ae5fe7654b5b2b4463375ff7ffb490aa0032f3a",
    chainid: 137
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.TxStatus",
    description: "Checks if a contract transaction executed successfully or encountered errors with detailed error messages",
    url: "https://api.etherscan.io/v2/api",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &Base.add_api_key/1
    },
    schema: %{
      type: :object,
      properties: %{
        chainid: %{
          type: :integer,
          description: "Network identifier (1=Ethereum, 137=Polygon, 56=BSC, etc.)",
          default: 1
        },
        txhash: %{
          type: :string,
          description: "Transaction hash to check contract execution status for (must be valid 66-character hex format)",
          pattern: "^0x[a-fA-F0-9]{64}$"
        }
      },
      required: ["txhash"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Set module and action for this endpoint
    params
    |> Map.put(:module, "transaction")
    |> Map.put(:action, "getstatus")
  end

  @doc """
  Transforms the API response into a more usable format.
  For contract execution status, we need to extract the status from the result.
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} when is_map(result) ->
        # Extract the status and error message if any
        status = Map.get(result, "isError", "0")
        error_message = Map.get(result, "errDescription", "")

        # Return a structured response with the status and message
        {:ok, %{
          result: %{
            status: status,
            is_error: status == "1",
            error_message: error_message
          }
        }}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end
end
