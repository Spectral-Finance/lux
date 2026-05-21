defmodule Lux.Prisms.Coinbase.CoinbasePortfolioPrism do
  @moduledoc """
  A prism that fetches portfolio balances on Coinbase.

  ## Example

      iex> Lux.Prisms.Coinbase.CoinbasePortfolioPrism.run(%{})

  The prism reads authentication details from configuration:
  - :coinbase_api_key
  - :coinbase_api_secret
  """

  use Lux.Prism,
    name: "Coinbase Portfolio",
    description: "Fetches balances and accounts on Coinbase Advanced Trade",
    input_schema: %{
      type: :object,
      properties: %{
        limit: %{
          type: :integer,
          description: "Limit of accounts to retrieve",
          default: 49
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        portfolio: %{type: :object, description: "Raw response from Coinbase API"}
      },
      required: ["status", "portfolio"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, api_key} <- get_api_key(),
         {:ok, api_secret} <- get_api_secret(),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("coinbase.rest"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("coinbase_utils.setup"),
         {:ok, result} <- get_portfolio(api_key, api_secret, input) do
      {:ok, %{status: "success", portfolio: result}}
    else
      {:error, :missing_api_key} ->
        {:error, "Coinbase API Key is not configured"}

      {:error, :missing_api_secret} ->
        {:error, "Coinbase API Secret is not configured"}

      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import required packages: #{error}"}

      {:error, reason} ->
        {:error, reason}
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

  defp get_portfolio(api_key, api_secret, params) do
    python_result =
      python variables: %{
               api_key: api_key,
               api_secret: api_secret,
               params: params
             } do
        ~PY"""
        from coinbase_utils.setup import setup
        import traceback

        try:
            client = setup(api_key, api_secret)
            limit = params.get("limit", 49)
            
            # Coinbase Advanced Trade get_accounts API
            accounts_result = client.get_accounts(limit=limit)
            
            # Convert Coinbase SDK objects to dicts if necessary, but usually it returns a dict or object
            if hasattr(accounts_result, 'to_dict'):
                accounts_result = accounts_result.to_dict()
                
            accounts_result
        except Exception as e:
            {"error": str(e), "traceback": traceback.format_exc()}
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end
end
