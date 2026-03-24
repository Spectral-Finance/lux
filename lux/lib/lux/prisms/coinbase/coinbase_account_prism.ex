defmodule Lux.Prisms.Coinbase.CoinbaseAccountPrism do
  @moduledoc """
  A prism that fetches account information from the Coinbase Exchange.

  ## Example

      # Get all accounts
      iex> Lux.Prisms.Coinbase.CoinbaseAccountPrism.run(%{})
      {:ok,
       %{
         status: "success",
         accounts: [
           %{
             "id" => "account_id",
             "currency" => "BTC",
             "balance" => "0.5",
             "available" => "0.4",
             "hold" => "0.1"
           }
         ]
       }}

      # Get specific account
      iex> Lux.Prisms.Coinbase.CoinbaseAccountPrism.run(%{
      ...>   account_id: "account_id_here"
      ...> })

      # Get account holds
      iex> Lux.Prisms.Coinbase.CoinbaseAccountPrism.run(%{
      ...>   account_id: "account_id_here",
      ...>   get_holds: true
      ...> })

  The prism reads authentication details from configuration:
  - :coinbase_api_key - Coinbase API key
  - :coinbase_api_secret - Coinbase API secret (base64 encoded)
  - :coinbase_api_passphrase - Coinbase API passphrase
  """

  use Lux.Prism,
    name: "Coinbase Account Info",
    description: "Fetches account information from Coinbase Exchange",
    input_schema: %{
      type: :object,
      properties: %{
        account_id: %{
          type: :string,
          description: "Specific account ID to fetch"
        },
        get_holds: %{
          type: :boolean,
          description: "Get holds for the specified account",
          default: false
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        accounts: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              id: %{type: :string},
              currency: %{type: :string},
              balance: %{type: :string},
              available: %{type: :string},
              hold: %{type: :string},
              profile_id: %{type: :string},
              trading_enabled: %{type: :boolean}
            }
          }
        },
        holds: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              id: %{type: :string},
              account_id: %{type: :string},
              created_at: %{type: :string},
              updated_at: %{type: :string},
              amount: %{type: :string},
              type: %{type: :string},
              ref: %{type: :string}
            }
          }
        },
        error: %{type: :string}
      },
      required: ["status"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, api_key} <- get_api_key(),
         {:ok, api_secret} <- get_api_secret(),
         {:ok, passphrase} <- get_passphrase(),
         {:ok, base_url} <- {:ok, Config.coinbase_api_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("coinbase_utils.setup"),
         {:ok, result} <- fetch_accounts(api_key, api_secret, passphrase, base_url, input) do
      {:ok, result}
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
        {:error, "Failed to fetch account info: #{inspect(reason)}"}
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

  defp fetch_accounts(api_key, api_secret, passphrase, base_url, params) do
    python_result =
      python variables: %{
               api_key: api_key,
               api_secret: api_secret,
               passphrase: passphrase,
               base_url: base_url,
               params: params
             } do
        ~PY"""
        from coinbase_utils.setup import setup

        rest_client, _ = setup(api_key, api_secret, passphrase, base_url)

        account_id = params.get("account_id")
        get_holds = params.get("get_holds", False)

        try:
            if account_id:
                if get_holds:
                    holds = rest_client.get_account_holds(account_id)
                    {"status": "success", "holds": holds}
                else:
                    account = rest_client.get_account(account_id)
                    {"status": "success", "accounts": [account]}
            else:
                accounts = rest_client.get_accounts()
                {"status": "success", "accounts": accounts}
        except Exception as e:
            {"status": "error", "error": str(e)}
        """
      end

    case python_result do
      %{"status" => "error", "error" => error} -> {:error, error}
      %{"status" => "success"} = result -> {:ok, result}
    end
  end
end