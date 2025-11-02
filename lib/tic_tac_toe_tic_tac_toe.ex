defmodule TicTacToe do
  use GenServer
  @moduledoc """
  Documentation for `TicTacToe`.
  """


  @impl true
  def init(name) do
    {:ok, name}
  end


  @impl true
  def handle_call(:greet, _from, name) do
    {:reply, "Hello, #{name}", name}
  end


  @impl true
  def handle_cast({:rename, name}, _) do
    {:noreply, name}
  end
  @doc """
  Hello world.

  ## Examples

      iex> TicTacToe.hello()
      :world

  """
  def hello do
    :world
  end
end
