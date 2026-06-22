defmodule Lux.Integrations.Telegram.Analytics do
  @moduledoc "Telegram Analytics bounty #67."
  use GenServer
  alias Lux.Integrations.Telegram.Client
  @spec start_link(list()) :: GenServer.on_start()
  def start_link(o=[]), do: GenServer.start_link(__MODULE__,o,name:__MODULE__)
  @spec analyze_growth(String.t()) :: {:ok,map()}|{:error,term()}
  def analyze_growth(id), do: GenServer.call(__MODULE__,{:growth,id})
  @spec engagement_metrics(String.t()) :: {:ok,map()}|{:error,term()}
  def engagement_metrics(id), do: GenServer.call(__MODULE__,{:eng,id})
  @spec message_performance(String.t(),integer()) :: {:ok,[map()]}|{:error,term()}
  def message_performance(id,l), do: GenServer.call(__MODULE__,{:perf,id,l})
  @spec generate_report(String.t(),atom()) :: {:ok,map()}|{:error,term()}
  def generate_report(id,t), do: GenServer.call(__MODULE__,{:report,id,t})
  @spec sentiment_trend(String.t()) :: {:ok,[map()]}|{:error,term()}
  def sentiment_trend(id), do: GenServer.call(__MODULE__,{:sent,id})
  @impl true
  def init(_), do: {:ok,%{history:%{},reports:%{}}}
  @impl true
  def handle_call({:growth,id},_,s) do
    case Client.get_chat_member_count(id) do
      {:ok,cnt} -> {:reply,{:ok,%{chat_id:id,current:cnt}},s}
      {:error,r} -> {:reply,{:error,r},s}
    end
  end
  @impl true
  def handle_call({:eng,id},_,s) do
    case Client.get_chat_stats(id) do
      {:ok,st} -> {:reply,{:ok,st},s}
      {:error,r} -> {:reply,{:error,r},s}
    end
  end
  @impl true
  def handle_call({:perf,id,lim},_,s) do
    case Client.get_chat_history(id,lim) do
      {:ok,msgs}->
        ranked=Enum.map(msgs,fn m->%{id:m.id,views:Map.get(m,:views,1),score:(Map.get(m,:forwards,0)*3+Map.get(m,:replies,0)*2)/(Map.get(m,:views,1)||1)} end)|>Enum.sort_by(fn x->x.score,:desc)
        {:reply,{:ok,ranked},s}
      {:error,r}->{:reply,{:error,r},s}
    end
  end
  @impl true
  def handle_call({:report,id,type},_,s) do
    rpt=%{type:type,chat_id:id,generated_at:DateTime.utc_now()|>DateTime.to_iso8601()}
    {:reply,{:ok,rpt},Map.put(s.reports,id<>type<>"_rpt",rpt)}
  end
  @impl true
  def handle_call({:sent,id},_,s) do
    case Client.get_chat_history(id,200) do
      {:ok,msgs}->
        sms=Enum.map(msgs,fn m->%{timestamp:Map.get(m,:date,DateTime.utc_now()),sentiment::neutral} end)
        {:reply,{:ok,sms},s}
      {:error,r}->{:reply,{:error,r},s}
    end
  end
end