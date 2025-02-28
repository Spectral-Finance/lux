defmodule Lux.Lenses.Etherscan.GasLens do
  @moduledoc """
  Lens for fetching gas-related data from the Etherscan API.

  This lens provides access to various gas-related endpoints for Ethereum,
  including gas price estimates, gas oracle data, and historical gas statistics.

  ## Examples

  ```elixir
  # Get gas price estimation for confirmation time
  Lux.Lenses.Etherscan.GasLens.get_gas_estimate(%{
    gasprice: "2000000000"
  })

  # Get current gas oracle data
  Lux.Lenses.Etherscan.GasLens.get_gas_oracle()

  # Get daily average gas limit
  Lux.Lenses.Etherscan.GasLens.get_daily_avg_gas_limit(%{
    startdate: "2023-01-01",
    enddate: "2023-01-31",
    sort: "asc"
  })
  ```
  """

  alias Lux.Lenses.Etherscan.BaseLens
  alias Lux.Config

  @base_url "https://api.etherscan.io/v2/api"

  @doc """
  Returns the estimated time, in seconds, for a transaction to be confirmed on the blockchain.

  ## Parameters

  - `gasprice`: The price paid per unit of gas, in wei
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: estimate}}`: Estimated confirmation time in seconds
  - `{:error, reason}`: Error message on failure
  """
  def get_gas_estimate(params) do
    # Validate required parameters
    with {:ok, _} <- validate_required(params, [:gasprice]) do
      # Build request parameters
      request_params = %{
        module: "gastracker",
        action: "gasestimate",
        gasprice: params[:gasprice]
      }

      # Make the API request
      make_request(request_params, params[:network])
    end
  end

  @doc """
  Returns the current Safe, Proposed and Fast gas prices.

  Post EIP-1559 changes:
  - Safe/Proposed/Fast gas price recommendations are now modeled as Priority Fees
  - Includes suggestBaseFee (the baseFee of the next pending block)
  - Includes gasUsedRatio to estimate how busy the network is

  ## Parameters

  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: oracle_data}}`: Gas oracle data including suggested gas prices
  - `{:error, reason}`: Error message on failure
  """
  def get_gas_oracle(params \\ %{}) do
    # Build request parameters
    request_params = %{
      module: "gastracker",
      action: "gasoracle"
    }

    # Make the API request
    make_request(request_params, params[:network])
  end

  @doc """
  Returns the historical daily average gas limit of the Ethereum network.

  Note: This endpoint is Pro-only and throttled to 2 calls/second.

  ## Parameters

  - `startdate`: The starting date in yyyy-MM-dd format, e.g., "2023-01-01"
  - `enddate`: The ending date in yyyy-MM-dd format, e.g., "2023-01-31"
  - `sort`: The sorting preference, "asc" for ascending, "desc" for descending (default: "asc")
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: gas_limit_data}}`: Daily average gas limit data
  - `{:error, reason}`: Error message on failure
  """
  def get_daily_avg_gas_limit(params) do
    # Validate required parameters
    with {:ok, _} <- validate_required(params, [:startdate, :enddate]),
         {:ok, _} <- validate_date_format(params, :startdate),
         {:ok, _} <- validate_date_format(params, :enddate) do
      # Check if Pro API key is available
      if !is_pro_api_key() do
        {:error, "This endpoint requires a Pro API key subscription"}
      else
        # Build request parameters
        request_params = %{
          module: "stats",
          action: "dailyavggaslimit",
          startdate: params[:startdate],
          enddate: params[:enddate],
          sort: params[:sort] || "asc"
        }

        # Make the API request
        make_request(request_params, params[:network])
      end
    end
  end

  @doc """
  Returns the total amount of gas used daily for transactions on the Ethereum network.

  Note: This endpoint is Pro-only and throttled to 2 calls/second.

  ## Parameters

  - `startdate`: The starting date in yyyy-MM-dd format, e.g., "2023-01-01"
  - `enddate`: The ending date in yyyy-MM-dd format, e.g., "2023-01-31"
  - `sort`: The sorting preference, "asc" for ascending, "desc" for descending (default: "asc")
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: gas_used_data}}`: Daily total gas used data
  - `{:error, reason}`: Error message on failure
  """
  def get_daily_gas_used(params) do
    # Validate required parameters
    with {:ok, _} <- validate_required(params, [:startdate, :enddate]),
         {:ok, _} <- validate_date_format(params, :startdate),
         {:ok, _} <- validate_date_format(params, :enddate) do
      # Check if Pro API key is available
      if !is_pro_api_key() do
        {:error, "This endpoint requires a Pro API key subscription"}
      else
        # Build request parameters
        request_params = %{
          module: "stats",
          action: "dailygasused",
          startdate: params[:startdate],
          enddate: params[:enddate],
          sort: params[:sort] || "asc"
        }

        # Make the API request
        make_request(request_params, params[:network])
      end
    end
  end

  @doc """
  Returns the daily average gas price used on the Ethereum network.

  Note: This endpoint is Pro-only and throttled to 2 calls/second.

  ## Parameters

  - `startdate`: The starting date in yyyy-MM-dd format, e.g., "2023-01-01"
  - `enddate`: The ending date in yyyy-MM-dd format, e.g., "2023-01-31"
  - `sort`: The sorting preference, "asc" for ascending, "desc" for descending (default: "asc")
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: gas_price_data}}`: Daily average gas price data
  - `{:error, reason}`: Error message on failure
  """
  def get_daily_avg_gas_price(params) do
    # Validate required parameters
    with {:ok, _} <- validate_required(params, [:startdate, :enddate]),
         {:ok, _} <- validate_date_format(params, :startdate),
         {:ok, _} <- validate_date_format(params, :enddate) do
      # Check if Pro API key is available
      if !is_pro_api_key() do
        {:error, "This endpoint requires a Pro API key subscription"}
      else
        # Build request parameters
        request_params = %{
          module: "stats",
          action: "dailyavggasprice",
          startdate: params[:startdate],
          enddate: params[:enddate],
          sort: params[:sort] || "asc"
        }

        # Make the API request
        make_request(request_params, params[:network])
      end
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

  defp validate_date_format(params, key) do
    if Map.has_key?(params, key) do
      date = params[key]
      # Check if date matches yyyy-MM-dd format
      if Regex.match?(~r/^\d{4}-\d{2}-\d{2}$/, date) do
        {:ok, params}
      else
        raise ArgumentError, "#{key} must be in yyyy-MM-dd format, e.g., 2023-01-31"
      end
    else
      {:ok, params}
    end
  end

  # Check if Pro API key is available
  defp is_pro_api_key do
    Config.etherscan_api_key_pro?()
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
