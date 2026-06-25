defmodule Lux.Integrations.MultiChain.Aggregator do
  @moduledoc "Multi-Chain Data Aggregation ($1750 bounty #74)."
  use GenServer
  alias Lux.Integrations.MultiChain.{ChainAdapter,Cache}
  @spec start_link(list()) :: GenServer.on_start()
  def start_link(o=[]), do: GenServer.start_link(__MODULE__,o,name:__MODULE__)
  @spec get_portfolio(String.t()) :: {:ok,map()}|{:error,term()}
  def get_portfolio(a), do: GenServer.call(__MODULE__,{:portfolio,a})
  @spec aggregate_price(String.t()) :: {:ok,map()}|{:error,term()}
  def aggregate_price(t), do: GenServer.call(__MODULE__,{:price,t})
  @spec get_tvl(atom()) :: {:ok,number()}|{:error,term()}
  def get_tvl(c=:ethereum), do: GenServer.call(__MODULE__,{:tvl,c})
  @spec get_gas_prices() :: map()
  def get_gas_prices, do: GenServer.call(__MODULE__,:gas)
  @spec chain_health() :: map()
  def chain_health, do: GenServer.call(__MODULE__,:health)
  @impl true
  def init(_), do: {:ok,%{chains:[:ethereum,:polygon,:arbitrum,:optimism,:base,:bnb],cache:Cache.new()}}
  @impl true
  def handle_call({:portfolio,addr},_,s) do
    bs=Enum.map(s.chains,fn c-> case ChainAdapter.get_balance(addr,c) do {:ok,b}->{Atom.to_string(c),b};_->{Atom.to_string(c),nil} end end)
    |> Enum.filter(fn{_,v}->not is_nil(v) end)
    {:reply,{:ok,%{address:addr,chains:Map.new(bs)}},s}
  end
  @impl true
  def handle_call({:price,tok},_,s) do
    ps=Enum.map(s.chains,fn c-> case ChainAdapter.get_token_price(tok,c) do {:ok,p}->{Atom.to_string(c),p};_->{Atom.to_string(c),nil} end end)
    |> Enum.filter(fn{_,v}->not is_nil(v) end)
    case ps do
      [_|_]=vp-> avg=vp|>Enum.map(fn{_,p}->p end)|>Enum.sum()/length(vp)
        {:reply,{:ok,%{token:tok,prices:Map.new(ps),average:avg}},s}
      []-> {:reply,{:error,"no data"},s}
    end
  end
  @impl true
  def handle_call({:tvl,c},_,s), do: ChainAdapter.get_tvl(c)
  @impl true
  def handle_call(:gas,_,s) do
    ps=Enum.map(s.chains,fn c-> case ChainAdapter.get_gas_price(c) do {:ok,p}->{Atom.to_string(c),p};_->{Atom.to_string(c),nil} end end)
    {:reply,Map.new(ps),s}
  end
  @impl true
  def handle_call(:health,_,s) do
    h=Enum.map(s.chains,fn c->{Atom.to_string(c),ChainAdapter.check_health(c)} end)
    {:reply,Map.new(h),s}
  end
end