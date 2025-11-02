defmodule TicTacToe do
  use GenServer
  @moduledoc """
  Documentation for `TicTacToe`.
  """

  defmodule Game do

    def choose(board, choice) do
      case Enum.at(board, choice) do
        nil -> {:ok, List.update_at(board, choice, fn _ -> activePlayer(board) end)}
        _ -> :error
      end
    end

    def activePlayer(board) do
      xs = Enum.count(board, fn v -> v == :x end)
      os = Enum.count(board, fn v -> v == :o end)


      if xs > os do
        :o
      else
        :x
      end
      end
  end

  ## Client
  def join() do
    IO.inspect("someone joined!")
    GenServer.call(__MODULE__, :join)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @impl true
  def init(_) do
    {:ok, %{players: [], board: [nil, nil, nil, nil, nil, nil, nil ,nil, nil]}}
  end


  @impl true
  def handle_call(:greet, _from, name) do
    {:reply, "Hello, #{name}", name}
  end

  def handle_call(:join, {pid, _}, state) do
    IO.inspect(state, label: "player joining the game")
    if Enum.count(state.players) < 2 do
      players = [ pid | state.players]
      state = Map.put(state, :players, players)
      case players do
        [p1, _] ->
          send(p1, {:ok, %{status: :your_turn, board: state.board}})
          {:reply, {:ok, %{status: :other_turn, board: state.board}}, state}
        _ -> {:reply, {:ok, %{status: :waiting, board: state.board}}, state}

      end
    else
      {:reply, {:error, "game is full"}, state}
    end
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
