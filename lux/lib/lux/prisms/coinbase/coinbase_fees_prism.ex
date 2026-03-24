defmodule Lux.Prisms.Coinbase.CoinbaseFeesPrism do
  @moduledoc """
  A prism that fetches current fee rates from the Coinbase Exchange.

  ## Example

      iex> Lux.Prisms.Coinbase.CoinbaseFeesPrism.run(%{})
      {:ok,
       %{
         status: "success",
         fees: %{
           "maker_fee_rate" => "0.005",
           "taker_fee_rate" => "0.005",
           "usd_volume" => "10000.00"
         }
       }}

  The prism reads authentication details from configuration:
  - :coinbase_api_key - Coinbase API key
  - :coinbase_api_secret - Coinbase API secret (base64 encoded)
  - :coinbase_api_passphrase - Coinbase API passphrase
  """

  use Lux.Prism,
    name: "Coinbase Fees",
    description: "Fetches current fee rates from Coinbase Exchange",
    input_schema: %{
      type: :object,
      properties: %{}
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        fees: %{
          type: :object,
          properties: %{
            maker_fee_rate: %{type: :string},
            taker_fee_rate: %{type: :string},
            usd_volume: %{type: :string}
          }
        },
        error: %{type: :string}
      },
      required: ["status"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python

  def handler(_input, _ctx) do
    with {:ok, api_key} <- get_api_key(),
         {:ok, api_secret} <- get_api_secret(),
         {:ok, passphrase} <- get_passphrase(),
         {:ok, base_url} <- {:ok, Config.coinbase_api_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("coinbase_utils.setup"),
         {:ok, result} <- fetch_fees(api_key, api_secret, passphrase, base_url) do
      {:ok, %{status: "success", fees: result}}
    else
      {:error, :missing_api_key} ->
        {:error, "Coinbase API key is not configured"}

      {:error, :missing_api_secret} ->
        {:error, "Coinbase API secret is not configured"}

      {:error, :missing_passphrase} ->
        {:error, "Coinbase API passphrase is not configured"}

      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import required packages: #{error}"}

      {:error, reason} when is_binary(reason) ->
        {:error, reason}

      {:error, reason} ->
        {:error, "Failed to fetch fees: #{inspect(reason)}"}
    end
  end

  defp get_api_key do
    {:ok, Config.coinbase_api_key()}
  rescue
    RuntimeError -> {:error, :missing_api_key}
  end

  defp get_api_secret do
    {:ok, Config.coinbase_api_secret()}
  rescue
    RuntimeError -> {:error, :missing_api_secret}
  end

  defp get_passphrase do
    {:ok, Config.coinbase_api_passphrase()}
  rescue
    RuntimeError -> {:error, :missing_passphrase}
  end

  defp fetch_fees(api_key, api_secret, passphrase, base_url) do
    python_result =
      python variables: %{
               api_key: api_key,
               api_secret: api_secret,
               passphrase: passphrase,
               base_url: base_url
             } do
        ~PY"""
        from coinbase_utils.setup import setup

        rest_client, _ = setup(api_key, api_secret, passphrase, base_url)

        try:
            fees = rest_client.get_fees()
            fees
        except Exception as e:
            {"error": str(e)}
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end
end