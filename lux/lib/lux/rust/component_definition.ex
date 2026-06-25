defmodule Lux.Rust.ComponentDefinition do
  @moduledoc "Rust Component Definition bounty #103."
  @callback init :: map()
  @callback update(term()) :: map()
  @callback view() :: term()
  @callback handle_event(String.t(),term()) :: term()
  @spec define_component(String.t(),map()) :: map()
  def define_component(name,props), do: %{name:name,type::component,props:props,state:Map.get(props,:initial_state,%{}),hooks:Map.get(props,:hooks,[]),children:[],mounted:false,created_at:DateTime.utc_now()|>DateTime.to_iso8601()}
  @spec mount(map()) :: map()
  def mount(c), do: Map.update!(c,:hooks,&Enum.map(&1,fn %{type::on_mount,fn:fun}->case fun.() do {:ok,s}->%{type::on_mount,state:s};_->%{type::on_mount,state:c.state} end;h->h end))
  @spec update_component(map(),map()) :: map()
  def update_component(c,np), do: Map.update!(c,:props,&Map.merge(&1,np))
  @spec render(map()) :: term()
  def render(c), do: %{type:c.name,props:c.props,state:c.state,children:Enum.map(c.children,&render/1)}
  @spec add_child(map(),map()) :: map()
  def add_child(p,c), do: Map.update!(p,:children,&(&1++[mount(c)]))
  @spec create_plugin(String.t(),map()) :: map()
  def create_plugin(name,config), do: %{name:name,type::plugin,config:config,enabled:true,dependencies:Map.get(config,:dependencies,[])}
  @spec register_plugin(map(),map()) :: map()
  def register_plugin(c,p), do: Map.update!(c,:hooks,&(&1++[%{type::plugin,name:p.name,config:p.config}]))
end