defmodule Lux.Lenses.Etherscan.TxReceiptStatus do
  @moduledoc """
  Lens for checking the receipt status of a transaction from the Etherscan API.

  Note: Only applicable for post Byzantium Fork transactions.

  ## Examples

  ```elixir
  # Check transaction receipt status (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.TxReceiptStatus.focus(%{
    txhash: "0x513c1ba0bebf66436b5fed86ab668452b7805593c05073eb2d51d3a52f480a76"
  })

  # Check transaction receipt status on a specific chain
  Lux.Lenses.Etherscan.TxReceiptStatus.focus(%{
    txhash: "0x513c1ba0bebf66436b5fed86ab668452b7805593c05073eb2d51d3a52f480a76",
    chainid: 137
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.TxReceiptStatus",
    description: "Verifies if a transaction was successfully mined with status 1 (success) or 0 (failure)",
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
          description: "Transaction hash to check receipt status for (must be valid 66-character hex format)",
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
    |> Map.put(:action, "gettxreceiptstatus")
  end

  @doc """
  Transforms the API response into a more usable format.
  For transaction receipt status, we need to extract the status from the result.
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} when is_map(result) ->
        # Extract the status
        status = Map.get(result, "status", "0")

        # Return a structured response with the status
        {:ok, %{
          result: %{
            status: status,
            is_success: status == "1"
          }
        }}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end
end
