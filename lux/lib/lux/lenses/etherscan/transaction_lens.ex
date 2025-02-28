defmodule Lux.Lenses.Etherscan.TransactionLens do
  @moduledoc """
  Lens for fetching transaction data from the Etherscan API.

  This lens provides access to various transaction-related endpoints for Ethereum transactions,
  including contract execution status and transaction receipt status.

  ## Examples

  ```elixir
  # Get contract execution status for a transaction
  Lux.Lenses.Etherscan.TransactionLens.get_contract_execution_status(%{
    txhash: "0x15f8e5ea1079d9a0bb04a4c58ae5fe7654b5b2b4463375ff7ffb490aa0032f3a"
  })

  # Get transaction receipt status
  Lux.Lenses.Etherscan.TransactionLens.get_tx_receipt_status(%{
    txhash: "0x513c1ba0bebf66436b5fed86ab668452b7805593c05073eb2d51d3a52f480a76"
  })
  ```
  """

  alias Lux.Lenses.Etherscan.BaseLens
  alias Lux.Config

  @base_url "https://api.etherscan.io/v2/api"

  @doc """
  Fetches the contract execution status for a transaction.

  ## Parameters

  - `txhash`: Transaction hash
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: execution_status}}`: Contract execution status on success
  - `{:error, reason}`: Error message on failure
  """
  def get_contract_execution_status(params) do
    with {:ok, _} <- validate_required(params, [:txhash]),
         {:ok, _} <- validate_tx_hash(params[:txhash]) do
      # Build request parameters
      request_params = %{
        module: "transaction",
        action: "getstatus",
        txhash: params[:txhash]
      }

      make_request(request_params, params[:network])
    end
  end

  @doc """
  Fetches the transaction receipt status for a transaction.

  ## Parameters

  - `txhash`: Transaction hash
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: receipt_status}}`: Transaction receipt status on success
  - `{:error, reason}`: Error message on failure

  ## Note

  Only applicable for post Byzantium Fork transactions.
  """
  def get_tx_receipt_status(params) do
    with {:ok, _} <- validate_required(params, [:txhash]),
         {:ok, _} <- validate_tx_hash(params[:txhash]) do
      # Build request parameters
      request_params = %{
        module: "transaction",
        action: "gettxreceiptstatus",
        txhash: params[:txhash]
      }

      make_request(request_params, params[:network])
    end
  end

  # Helper functions for parameter validation
  defp validate_required(params, required_keys) do
    missing_keys = Enum.filter(required_keys, fn key -> !Map.has_key?(params, key) end)

    if Enum.empty?(missing_keys) do
      {:ok, params}
    else
      missing_key = List.first(missing_keys)
      raise ArgumentError, "#{missing_key} parameter is required"
    end
  end

  defp validate_tx_hash(hash) do
    case BaseLens.validate_tx_hash(hash) do
      {:ok, _} -> {:ok, hash}
      {:error, message} -> raise ArgumentError, message
    end
  end

  # Make API request with the given parameters
  defp make_request(params, network) do
    # Add API key and chainid to the parameters
    params_with_auth = params
    |> Map.put(:apikey, api_key())
    |> Map.put(:chainid, network_to_chain_id(network))

    case Req.get(@base_url, params: params_with_auth) do
      {:ok, %{status: 200, body: body}} ->
        BaseLens.process_response(body)
      {:ok, response} ->
        {:error, "Unexpected response: #{inspect(response)}"}
      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  # Get API key from application config
  defp api_key do
    Config.etherscan_api_key()
  end

  # Convert network to chain ID
  defp network_to_chain_id(nil), do: "1" # Default to Ethereum mainnet
  defp network_to_chain_id(network), do: Config.etherscan_chain_id(network)
end
