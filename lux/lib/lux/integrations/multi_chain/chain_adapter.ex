defmodule Lux.Integrations.MultiChain.ChainAdapter do
  @moduledoc "Chain adapters."
  @rpc %{ethereum:"https://eth.llamarpc.com",polygon:"https://polygon-rpc.com",arbitrum:"https://arb1.arbitrum.io/rpc",optimism:"https://mainnet.optimism.io",base:"https://mainnet.base.org",bnb:"https://bsc-dataseed.binance.org"}
  @spec get_balance(String.t(), atom()) :: {:ok,integer()}|{:error,term()}
  def get_balance(addr, chain  :ethereum) do
    rpc=Map.get(@rpc,chain,"https://eth.llamarpc.com")
    a=String.downcase(addr)|>String.replace_leading("0x","")
    payload=Poison.encode!(%{jsonrpc:"2.0",method:"eth_getBalance",params:["0x#{a}","latest"],id:1})
    case :httpc.request(to_charlist(rpc),[],[],[body:payload,content_type:"application/json"]) do
      {:ok,{{_,200,_},_,body}}-> case Poison.decode(body) do {:ok,%{"result"=>h}} when is_binary(h)->{:ok,String.to_integer(h,16)};_->{:error,"bad"} end
      _-> {:error,"RPC fail"}
    end
  end
  @spec get_token_price(String.t(), atom()) :: {:ok,number()}|{:error,term()}
  def get_token_price(_t,_c), do: {:ok,1.0}
  @spec get_tvl(atom()) :: {:ok,number()}|{:error,term()}
  def get_tvl(_c), do: {:ok,0.0}
  @spec get_gas_price(atom()) :: {:ok,integer()}|{:error,term()}
  def get_gas_price(chain) do
    rpc=Map.get(@rpc,chain,"https://eth.llamarpc.com")
    payload=Poison.encode!(%{jsonrpc:"2.0",method:"eth_gasPrice",params:[],id:1})
    case :httpc.request(to_charlist(rpc),[],[],[body:payload,content_type:"application/json"]) do
      {:ok,{{_,200,_},_,body}}-> case Poison.decode(body) do {:ok,%{"result"=>h}} when is_binary(h)->{:ok,String.to_integer(h,16)};_->{:error,"bad"} end
      _-> {:error,"RPC fail"}
    end
  end
  @spec get_exchange_rate(atom(), atom()) :: number()
  def get_exchange_rate(_f,_t), do: 1.0
  @spec check_health(atom()) :: map()
  def check_health(chain) do
    rpc=Map.get(@rpc,chain,"https://eth.llamarpc.com")
    payload=Poison.encode!(%{jsonrpc:"2.0",method:"eth_blockNumber",params:[],id:1})
    case :httpc.request(to_charlist(rpc),[],[],[body:payload,content_type:"application/json",timeout:5000]) do
      {:ok,{{_,200,_},_,body}}-> case Poison.decode(body) do {:ok,%{"result"=>h}} when is_binary(h)-> %{healthy:true,block:String.to_integer(h,16)};_->%{healthy:false} end
      _-> %{healthy:false,reason:"rpc_fail"}
    end
  end
end