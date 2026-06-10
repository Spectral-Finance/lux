defmodule Lux.RustComponent do
  @moduledoc """
  This module provides the interface for defining Rust components in the Lux framework.
  """
  
  alias Lux.Component
  
  @doc """
  Defines a new Rust component for Lux framework.
  """
  def define(name, implementation) do
    Component.add_component(name, implementation)
  end
  
  @doc """
  Initializes a Rust component with the given implementation.
  """
  def initialize_component(name, implementation) do
    Lux.RustComponent.Definition.define(name, implementation)
  end
  
  def run_component(name) do
    Lux.run_component(name)
  end
end