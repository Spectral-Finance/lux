defmodule Lux.Integrations.Youtube.ContentCreator do
  @moduledoc "YouTube Content Creation bounty #71."
  use GenServer
  alias Lux.Integrations.Youtube.Core
  alias Lux.LLM
  @spec start_link(list()) :: GenServer.on_start()
  def start_link(o=[]), do: GenServer.start_link(__MODULE__,o,name:__MODULE__)
  @spec generate_script(String.t(),String.t()) :: {:ok,map()}|{:error,term()}
  def generate_script(topic,nc), do: GenServer.call(__MODULE__,{:script,topic, nc})
  @spec create_draft(map()) :: {:ok,map()}|{:error,term()}
  def create_draft(meta), do: GenServer.call(__MODULE__,{:draft,meta})
  @spec optimize_seo(String.t(),String.t()) :: {:ok,map()}|{:error,term()}
  def optimize_seo(title,desc), do: GenServer.call(__MODULE__,{:seo,title,desc})
  @spec schedule_content(atom(),DateTime.t(),map()) :: {:ok,map()}|{:error,term()}
  def schedule_content(type,time,meta), do: GenServer.call(__MODULE__,{:sched,type,time,meta})
  @spec get_schedule() :: [map()]
  def get_schedule, do: GenServer.call(__MODULE__,:sched_list)
  @impl true
  def init(_), do: {:ok,%{drafts:%{},calendar:[]}}
  @impl true
  def handle_call({:script,topic, _nc},_,s) do
    prompt="Write a YouTube script about "+topic
    case LLM.generate(prompt) do
      {:ok,script}->
        id=:crypto.strong_rand_bytes(16)|>Base.hex_encode32(padding:false)
        draft=%{id:id,type::script,topic:topic,content:script,created_at:DateTime.utc_now()|>DateTime.to_iso8601(),status::draft}
        {:reply,{:ok,draft},Map.update!(s,:drafts,&Map.put(&1,id,draft))}
      {:error,r}->{:reply,{:error,r},s}
    end
  end
  @impl true
  def handle_call({:draft,meta},_,s) do
    id=:crypto.strong_rand_bytes(16)|>Base.hex_encode32(padding:false)
    d=meta|>Map.put_new(:id,id)|>Map.put_new(:created_at,DateTime.utc_now()|>DateTime.to_iso8601())|>Map.put_new(:status,"draft")
    {:reply,{:ok,d},Map.update!(s,:drafts,&Map.put(&1,id,d))}
  end
  @impl true
  def handle_call({:seo,title,desc},_,s) do
    prompt="Optimize for YouTube SEO. Title: "+title+". Desc: "+desc
    case LLM.generate(prompt) do
      {:ok,r}->{:reply,{:ok,%{original_title:title,optimized:r}},s}
      {:error,e}->{:reply,{:error,e},s}
    end
  end
  @impl true
  def handle_call({:sched,type,time,_meta},_,s) do
    e=%{type:type,scheduled_at:time,created_at:DateTime.utc_now()|>DateTime.to_iso8601()}
    {:reply,{:ok,e},Map.update!(s,:calendar,&Enum.sort([e|&1],fn a,b->DateTime.compare(a.scheduled_at,b.scheduled_at)==:lt end))}
  end
  @impl true
  def handle_call(:sched_list,_,s) do
    up=s.calendar|>Enum.filter(fn e->DateTime.compare(e.scheduled_at,DateTime.utc_now())==:gt end)|>Enum.take(20)
    {:reply,up,s}
  end
end