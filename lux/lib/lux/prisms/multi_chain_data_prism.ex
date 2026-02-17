defmodule Lux.Prisms.MultiChainDataPrism do
  @moduledoc """
  Prism for handling multi-chain data with common functionality.
  """

  @doc """
  Processes multi-chain data response.
  """
  def process_response(response) do
    cond do
      # Handle error object
      Map.has_key?(response, "error") ->
        {:error, response["error"]}

      # Handle successful response
      response["status"] == "1" ->
        {:ok, %{result: response["result"]}}

      # Handle error response
      response["status"] == "0" ->
        {:error, %{message: response["message"], result: response["result"]}}

      # Handle unexpected response format
      true ->
        {:error, "Unexpected response format: #{inspect(response)}"}
    end
  end

  @doc """
  Validates a chain ID.
  """
  def validate_chain_id(chain_id) when is_integer(chain_id) and chain_id >= 0 do
    {:ok, Integer.to_string(chain_id)}
  end

  @doc """
  Validates a network name.
  """
  def validate_network_name(name) when is_binary(name) do
    {:ok, name}
  end