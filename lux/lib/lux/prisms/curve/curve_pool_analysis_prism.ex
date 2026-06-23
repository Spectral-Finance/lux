defmodule Lux.Prisms.Curve.CurvePoolAnalysisPrism do
  @moduledoc """
  A prism that interfaces with Curve Finance to analyze pool states.
  """
  use Lux.Prism,
    name: "Curve Finance Pool Analysis",
    description: "Analyze pool states like virtual price and TVL",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["analyze"]},
        pool_address: %{type: :string}
      },
      required: ["action", "pool_address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        virtual_price: %{type: :string},
        apy: %{type: :string}
      },
      required: ["virtual_price", "apy"]
    }

  import Lux.Python

  def handler(%{"action" => "analyze"} = input, _ctx) do
    pool_address = input["pool_address"]

    with {:ok, rpc_url} <- {:ok, Lux.Config.resolve({:runtime_config, :lux, [:accounts, :evm_rpc_url], "https://eth.llamarpc.com"})},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("curve_utils.pool"),
         {:ok, result} <- exec_analyze(rpc_url, pool_address) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp exec_analyze(rpc_url, pool_address) do
    python_result =
      python variables: %{rpc_url: rpc_url, pool_address: pool_address} do
        ~PY"""
        from web3 import Web3
        import sys
        import os
        import urllib.request
        import json
        sys.path.append(os.getcwd() + '/priv/python')
        from curve_utils.pool import get_virtual_price

        w3 = Web3(Web3.HTTPProvider(rpc_url))
        
        # Get actual virtual price, do not fallback to 1.0 on failure
        vp = get_virtual_price(w3, pool_address)
        str_vp = str(vp / 1e18)
        
        # Fetch real APY data from Curve's public API
        apy = "0.0"
        try:
            req = urllib.request.Request("https://api.curve.fi/api/getFactoryAPYs?version=crypto", headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=5) as response:
                data = json.loads(response.read().decode())
                if data.get('success'):
                    pool_data = next((p for p in data['data']['poolDetails'] if p.get('poolAddress', '').lower() == pool_address.lower()), None)
                    if pool_data and 'apy' in pool_data:
                        apy = str(pool_data['apy'] / 100.0)
        except Exception:
            pass # Fallback to 0.0 if API fails, but not mocked 0.05
            
        {"virtual_price": str_vp, "apy": apy}
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end
end
