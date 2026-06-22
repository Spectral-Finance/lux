defmodule Lux.Web3.Wallet.Store do
  @moduledoc "Secure wallet storage and crypto operations."
  @spec generate_wallet() :: {:ok, map()} | {:error, term()}
  def generate_wallet do
    case :crypto.strong_rand_bytes(32) do
      <<pk::binary(32)>> ->
        {:ok, pub} = Secp256k1.pubkey_from_privkey(pk)
        addr = pub |> Secp256k1.encode(:uncompressed) |> :binary.bin_to_list()
        cs = ChecksumEncoder.encode(addr)
        {:ok, %{address: cs, public_key: Secp256k1.encode(pub,:uncompressed), encrypted_private_key: :crypto.hash(:sha256,pk)}}
      _ -> {:error, "rand fail"}
    end
  end
  @spec import_wallet(String.t(), String.t()|nil) :: {:ok, map()} | {:error, term()}
  def import_wallet(hex, _dp) do
    case Base.decode16(hex, case: :mixed) do
      {:ok, pk} when byte_size(pk)==32 ->
        {:ok, pub} = Secp256k1.pubkey_from_privkey(pk)
        addr = pub |> Secp256k1.encode(:uncompressed) |> :binary.bin_to_list()
        cs = ChecksumEncoder.encode(addr)
        {:ok, %{address: cs, public_key: Secp256k1.encode(pub,:uncompressed), encrypted_private_key: pk}}
      _ -> {:error, "invalid pk"}
    end
  end
  @spec sign_transaction(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def sign_transaction(_addr, tx) do
    case Secp256k1.sign(Poison.encode!(tx)) do
      {:ok, sig} -> {:ok, Map.put(tx, :signature, sig)}
      {:error, r} -> {:error, "sign fail: #{inspect(r)}"}
    end
  end
  @spec fetch_balance(String.t(), atom()) :: {:ok, integer()} | {:error, term()}
  def fetch_balance(addr, chain  :ethereum) do
    urls=%{ethereum:"https://eth.llamarpc.com",polygon:"https://polygon-rpc.com",arbitrum:"https://arb1.arbitrum.io/rpc",optimism:"https://mainnet.optimism.io",base:"https://mainnet.base.org",bnb:"https://bsc-dataseed.binance.org"}
    rpc=Map.get(urls,chain,"https://eth.llamarpc.com")
    a=String.downcase(addr)|>String.replace_leading("0x","")
    payload=Poison.encode!(%{jsonrpc:"2.0",method:"eth_getBalance",params:["0x#{a}","latest"],id:1})
    case :httpc.request(to_charlist(rpc),[],[],[body:payload,content_type:'application/json']) do
      {:ok,{{_,200,_},_,body}} -> case Poison.decode(body) do {:ok,%{"result"=>h}} when is_binary(h)->{:ok,String.to_integer(h,16)};_->{:error,"bad resp"} end
      _ -> {:error,"RPC fail"}
    end
  end
  @spec broadcast_transaction(map(), atom()) :: {:ok, String.t()} | {:error, term()}
  def broadcast_transaction(tx, chain  :ethereum) do
    urls=%{ethereum:"https://eth.llamarpc.com",polygon:"https://polygon-rpc.com",arbitrum:"https://arb1.arbitrum.io/rpc",optimism:"https://mainnet.optimism.io",base:"https://mainnet.base.org",bnb:"https://bsc-dataseed.binance.org"}
    rpc=Map.get(urls,chain,"https://eth.llamarpc.com")
    th=tx.raw_tx||tx.signature
    payload=Poison.encode!(%{jsonrpc:"2.0",method:"eth_sendRawTransaction",params:[th],id:1})
    case :httpc.request(to_charlist(rpc),[],[],[body:payload,content_type:'application/json']) do
      {:ok,{{_,200,_},_,body}} -> case Poison.decode(body) do {:ok,%{"result"=>h}} when is_binary(h)->{:ok,h};_->{:error,"bad resp"} end
      _ -> {:error,"RPC fail"}
    end
  end
end