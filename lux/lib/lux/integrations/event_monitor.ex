defmodule Lux.Integrations.EventMonitor do
  @moduledoc "Smart Contract Event Monitoring (bounty #75).
  Real-time event log subscription, filtering, indexing, alerting.
  Supports multi-chain contract event monitoring.
  "
  use GenServer
  alias Lux.Integrations.EventMonitor.{Filter,Indexer,Subscriber}
  @spec start_link(list()) :: GenServer.on_start()
  def start_link(o), do: GenServer.start_link(__MODULE__,o,name:__MODULE__)
  @spec subscribe(String.t(),[String.t()],atom(),map()) :: {:ok,map()}|{:error,term()}
  def subscribe(c,topics,ch,o), do: GenServer.call(__MODULE__,{:sub,c,topics,ch,o})
  @spec unsubscribe(String.t()) :: :ok|{:error,term()}
  def unsubscribe(id), do: GenServer.call(__MODULE__,{:unsub,id})
  @spec query_events(map()) :: [map()]
  def query_events(f), do: GenServer.call(__MODULE__,{:query,f})
  @spec stats() :: map()
  def stats, do: GenServer.call(__MODULE__,:stats)
  @spec add_alert(String.t(),map()) :: {:ok,map()}|{:error,term()}
  def add_alert(n,r), do: GenServer.call(__MODULE__,{:alert,n,r})
  @spec remove_alert(String.t()) :: :ok|{:error,term()}
  def remove_alert(n), do: GenServer.call(__MODULE__,{:rmalert,n})
  @spec list_alerts() :: [map()]
  def list_alerts, do: GenServer.call(__MODULE__,:alerts)
  @spec index_event(map()) :: :ok
  def index_event(e), do: GenServer.cast(__MODULE__,{:idx,e})
  @impl true
  def init(_), do: {:ok,%{subs:%{},idx:Indexer.new(),alerts:%{},stats:%{subs:0,idxed:0,triggered:0}}}
  @impl true
  def handle_call({:sub,c,t,ch,_},_,s) do
    id=Subscriber.generate_id()
    sub=%{id:id,contract:c,topics:t,chain:ch,created_at:DateTime.utc_now()|>DateTime.to_iso8601()}
    ns=Map.update!(s,:subs,&Map.put(&1,id,sub))
    {:reply,{:ok,sub},Map.update!(ns,:stats,&Map.put(&1,:subs,&1+1))}
  end
  @impl true
  def handle_call({:unsub,id},_,s) do
    case Map.pop(s.subs,id) do
      {nil,_} -> {:reply,{:error,"not found"},s}
      {_,subs} -> {:reply,:ok,%{s|subs:subs}}
    end
  end
  @impl true
  def handle_call({:query,f},_,s), do: {:reply,Indexer.query(s.idx,f),s}
  @impl true
  def handle_call(:stats,_,s), do: {:reply,s.stats,s}
  @impl true
  def handle_call({:alert,n,r},_,s) do
    a=%{name:n,rule:r,created_at:DateTime.utc_now()|>DateTime.to_iso8601(),triggered:0}
    {:reply,{:ok,a},Map.put(s.alerts,n,a)}
  end
  @impl true
  def handle_call({:rmalert,n},_,s), do: {:reply,:ok,Map.delete(s.alerts,n)}
  @impl true
  def handle_call(:alerts,_,s), do: {:reply,Map.values(s.alerts),s}
  @impl true
  def handle_cast({:idx,e},s) do
    idx=Indexer.insert(s.idx,e)
    trig=Enum.count(s.alerts,fn {_n,a}->Filter.matches?(a.rule,e) end)
    st=s.stats|>Map.update!(:idxed,&(&1+1))|>Map.update!(:triggered,&(&1+trig))
    {:noreply,%{s|idx:idx,stats:st}}
  end
end