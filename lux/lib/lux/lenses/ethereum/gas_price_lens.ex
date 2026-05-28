defmodule Lux.Lenses.Ethereum.GasPriceLens do
  @moduledoc """
  Lens for fetching current Ethereum gas prices from the Etherscan Gas Oracle API.

  Returns safe, proposed, and fast gas prices along with the current base fee,
  all expressed in Gwei.

  ## Examples

      iex> Lux.Lenses.Ethereum.GasPriceLens.focus(%{})
      {:ok, %{
        safe_gas_gwei: 20.0,
        propose_gas_gwei: 22.0,
        fast_gas_gwei: 25.0,
        base_fee_gwei: 19.12
      }}

      iex> Lux.Lenses.Ethereum.GasPriceLens.focus(%{api_key: "YOUR_KEY"})
      {:ok, %{safe_gas_gwei: 20.0, propose_gas_gwei: 22.0, fast_gas_gwei: 25.0, base_fee_gwei: 19.12}}
  """

  use Lux.Lens,
    name: "Ethereum Gas Price Oracle",
    description: "Fetches current Ethereum gas prices (safe, proposed, fast) and base fee in Gwei",
    url: "https://api.etherscan.io/api",
    method: :get,
    headers: [{"content-type", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        api_key: %{
          type: :string,
          description: "Etherscan API key (optional, uses free tier if omitted)"
        }
      },
      required: []
    }

  @doc """
  Prepares query parameters before making the API request.
  """
  def before_focus(params) do
    base_params =
      params
      |> Map.put(:module, "gastracker")
      |> Map.put(:action, "gasoracle")

    case Map.pop(base_params, :api_key) do
      {nil, rest} -> rest
      {key, rest} -> Map.put(rest, :apikey, key)
    end
  end

  @doc """
  Transforms the Etherscan API response into a structured gas price map.
  """
  @impl true
  def after_focus(%{"status" => "1", "result" => result}) when is_map(result) do
    {:ok,
     %{
       safe_gas_gwei: parse_float(Map.get(result, "SafeGasPrice", "0")),
       propose_gas_gwei: parse_float(Map.get(result, "ProposeGasPrice", "0")),
       fast_gas_gwei: parse_float(Map.get(result, "FastGasPrice", "0")),
       base_fee_gwei: parse_float(Map.get(result, "suggestBaseFee", "0"))
     }}
  end

  def after_focus(%{"status" => "0", "message" => message, "result" => result}) do
    {:error, %{message: message, result: result}}
  end

  def after_focus(response) do
    {:error, "Unexpected response format: #{inspect(response)}"}
  end

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {f, _} -> f
      :error -> 0.0
    end
  end

  defp parse_float(value) when is_number(value), do: value / 1
  defp parse_float(_), do: 0.0
end
