defmodule Lux.Lenses.Etherscan.LogsLens do
  @moduledoc """
  Lens for fetching event logs data from the Etherscan API.

  This lens provides access to various logs-related endpoints for Ethereum events,
  including filtering by address, topics, and block range.

  ## Examples

  ```elixir
  # Get event logs by address
  Lux.Lenses.Etherscan.LogsLens.get_logs_by_address(%{
    address: "0xbd3531da5cf5857e7cfaa92426877b022e612cf8",
    fromBlock: 12878196,
    toBlock: 12878196
  })

  # Get event logs by topics
  Lux.Lenses.Etherscan.LogsLens.get_logs_by_topics(%{
    fromBlock: 12878196,
    toBlock: 12879196,
    topic0: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
    topic1: "0x0000000000000000000000000000000000000000000000000000000000000000",
    topic0_1_opr: "and"
  })

  # Get event logs by address filtered by topics
  Lux.Lenses.Etherscan.LogsLens.get_logs(%{
    address: "0x59728544b08ab483533076417fbbb2fd0b17ce3a",
    fromBlock: 15073139,
    toBlock: 15074139,
    topic0: "0x27c4f0403323142b599832f26acd21c74a9e5b809f2215726e244a4ac588cd7d",
    topic1: "0x00000000000000000000000023581767a106ae21c074b2276d25e5c3e136a68b",
    topic0_1_opr: "and"
  })
  ```
  """

  alias Lux.Lenses.Etherscan.BaseLens
  alias Lux.Config

  @base_url "https://api.etherscan.io/v2/api"

  # Valid topic operators
  @valid_topic_operators ["and", "or"]

  # Valid topic combinations
  @valid_topic_combinations [
    "topic0_1_opr",
    "topic1_2_opr",
    "topic2_3_opr",
    "topic0_2_opr",
    "topic0_3_opr",
    "topic1_3_opr"
  ]

  @doc """
  Fetches event logs by address with optional filtering by block range.

  ## Parameters

  - `address`: The address to check for logs
  - `fromBlock`: The block number to start searching for logs (optional)
  - `toBlock`: The block number to stop searching for logs (optional)
  - `page`: The page number for pagination (default: 1)
  - `offset`: The number of records per page (default: 1000, max: 1000)
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: logs}}`: Event logs on success
  - `{:error, reason}`: Error message on failure
  """
  def get_logs_by_address(params) do
    # Validate required parameters
    with {:ok, _} <- validate_required(params, [:address]),
         {:ok, _} <- validate_address(params, :address),
         {:ok, _} <- validate_block_numbers(params) do
      # Build request parameters
      request_params = %{
        module: "logs",
        action: "getLogs",
        address: params[:address]
      }

      # Add optional parameters
      request_params = add_optional_params(request_params, params)

      # Make the API request
      make_request(request_params, params[:network])
    end
  end

  @doc """
  Fetches event logs filtered by topics and block range.

  ## Parameters

  - `fromBlock`: The block number to start searching for logs
  - `toBlock`: The block number to stop searching for logs
  - `topic0`, `topic1`, `topic2`, `topic3`: The topics to filter by (optional)
  - `topic0_1_opr`, `topic1_2_opr`, etc.: The operators between topics (optional, "and" or "or")
  - `page`: The page number for pagination (default: 1)
  - `offset`: The number of records per page (default: 1000, max: 1000)
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: logs}}`: Event logs on success
  - `{:error, reason}`: Error message on failure
  """
  def get_logs_by_topics(params) do
    # Validate required parameters
    with {:ok, _} <- validate_required(params, [:fromBlock, :toBlock]),
         {:ok, _} <- validate_block_numbers(params),
         {:ok, _} <- validate_topics(params),
         {:ok, _} <- validate_topic_operators(params) do
      # Build request parameters
      request_params = %{
        module: "logs",
        action: "getLogs"
      }

      # Add optional parameters
      request_params = add_optional_params(request_params, params)

      # Make the API request
      make_request(request_params, params[:network])
    end
  end

  @doc """
  Fetches event logs by address filtered by topics and block range.
  This is a convenience function that combines get_logs_by_address and get_logs_by_topics.

  ## Parameters

  - `address`: The address to check for logs
  - `fromBlock`: The block number to start searching for logs
  - `toBlock`: The block number to stop searching for logs
  - `topic0`, `topic1`, `topic2`, `topic3`: The topics to filter by (optional)
  - `topic0_1_opr`, `topic1_2_opr`, etc.: The operators between topics (optional, "and" or "or")
  - `page`: The page number for pagination (default: 1)
  - `offset`: The number of records per page (default: 1000, max: 1000)
  - `network`: Network to use (default: :ethereum)

  ## Returns

  - `{:ok, %{result: logs}}`: Event logs on success
  - `{:error, reason}`: Error message on failure
  """
  def get_logs(params) do
    # Validate required parameters
    with {:ok, _} <- validate_required(params, [:address, :fromBlock, :toBlock]),
         {:ok, _} <- validate_address(params, :address),
         {:ok, _} <- validate_block_numbers(params),
         {:ok, _} <- validate_topics(params),
         {:ok, _} <- validate_topic_operators(params) do
      # Build request parameters
      request_params = %{
        module: "logs",
        action: "getLogs",
        address: params[:address]
      }

      # Add optional parameters
      request_params = add_optional_params(request_params, params)

      # Make the API request
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

  defp validate_address(params, key) do
    if Map.has_key?(params, key) do
      case BaseLens.validate_eth_address(params[key]) do
        {:ok, _} -> {:ok, params}
        {:error, message} -> raise ArgumentError, message
      end
    else
      {:ok, params}
    end
  end

  defp validate_block_numbers(params) do
    # Validate fromBlock and toBlock if present
    block_keys = [:fromBlock, :toBlock]

    invalid_blocks = Enum.filter(block_keys, fn key ->
      Map.has_key?(params, key) &&
      !is_integer(params[key]) &&
      !Regex.match?(~r/^\d+$/, to_string(params[key]))
    end)

    if Enum.empty?(invalid_blocks) do
      {:ok, params}
    else
      invalid_key = List.first(invalid_blocks)
      raise ArgumentError, "#{invalid_key} must be a valid integer block number"
    end
  end

  defp validate_topics(params) do
    # Check if at least one topic is provided when using get_logs_by_topics
    topic_keys = [:topic0, :topic1, :topic2, :topic3]
    has_topics = Enum.any?(topic_keys, fn key -> Map.has_key?(params, key) end)

    # If this is a get_logs_by_topics call and no topics are provided, raise an error
    if !Map.has_key?(params, :address) && !has_topics do
      raise ArgumentError, "At least one topic parameter is required"
    end

    # Validate topic format (should be a hex string)
    invalid_topics = Enum.filter(topic_keys, fn key ->
      Map.has_key?(params, key) &&
      !Regex.match?(~r/^0x[0-9a-fA-F]+$/, to_string(params[key]))
    end)

    if Enum.empty?(invalid_topics) do
      {:ok, params}
    else
      invalid_key = List.first(invalid_topics)
      raise ArgumentError, "#{invalid_key} must be a valid hex string starting with 0x"
    end
  end

  defp validate_topic_operators(params) do
    # Validate topic operators if present
    invalid_operators = Enum.filter(@valid_topic_combinations, fn key ->
      Map.has_key?(params, String.to_atom(key)) &&
      !Enum.member?(@valid_topic_operators, params[String.to_atom(key)])
    end)

    if Enum.empty?(invalid_operators) do
      {:ok, params}
    else
      invalid_key = List.first(invalid_operators)
      raise ArgumentError, "#{invalid_key} must be either 'and' or 'or'"
    end
  end

  # Add optional parameters to the request
  defp add_optional_params(request_params, params) do
    # Block range parameters
    request_params = if Map.has_key?(params, :fromBlock) do
      Map.put(request_params, :fromBlock, params[:fromBlock])
    else
      request_params
    end

    request_params = if Map.has_key?(params, :toBlock) do
      Map.put(request_params, :toBlock, params[:toBlock])
    else
      request_params
    end

    # Pagination parameters
    request_params = Map.put(request_params, :page, params[:page] || 1)
    request_params = Map.put(request_params, :offset, params[:offset] || 1000)

    # Topic parameters
    topic_keys = [:topic0, :topic1, :topic2, :topic3]
    request_params = Enum.reduce(topic_keys, request_params, fn key, acc ->
      if Map.has_key?(params, key) do
        Map.put(acc, key, params[key])
      else
        acc
      end
    end)

    # Topic operator parameters
    operator_keys = @valid_topic_combinations
    request_params = Enum.reduce(operator_keys, request_params, fn key, acc ->
      atom_key = String.to_atom(key)
      if Map.has_key?(params, atom_key) do
        Map.put(acc, atom_key, params[atom_key])
      else
        acc
      end
    end)

    request_params
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
