defmodule TicTacToe do
  use GenServer

  @moduledoc """
  Documentation for `TicTacToe`.
  """

  defmodule Game do
    def winner?(board) do
      cols = board |> Enum.chunk_every(3)
      r1 = board |> Enum.take_every(3)
      r2 = board |> Enum.drop(1) |> Enum.take_every(3)
      r3 = board |> Enum.drop(2) |> Enum.take_every(3)
      diag1 = [board |> Enum.at(0), board |> Enum.at(4), board |> Enum.at(8)]
      diag2 = [board |> Enum.at(2), board |> Enum.at(4), board |> Enum.at(6)]

      lines =
        cols ++
          [
            r1,
            r2,
            r3,
            diag1,
            diag2
          ]

      Enum.find_value(lines, fn
        [:x, :x, :x] -> :x
        [:o, :o, :o] -> :o
        _ -> nil
      end)
    end

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
  def join(code) do
    case Registry.lookup(TicTacToe.Registry, code) do
      [{pid, _}] -> GenServer.call(pid, :join)
      [] -> {:error, :not_found}
    end
  end

  def choose(code, location) do
    name = {:via, Registry, {TicTacToe.Registry, code}}
    GenServer.call(name, {:choose, location})
  end

  def restart(code) do
    name = {:via, Registry, {TicTacToe.Registry, code}}
    GenServer.cast(name, :restart)
  end

  def start_link(code, opts \\Keyword.new()) do
    name = {:via, Registry, {TicTacToe.Registry, code}}
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, name))
  end

  def kill(code) do
    name = {:via, Registry, {TicTacToe.Registry, code}}
    GenServer.stop(name)
  end

  @impl true
  def init(_) do
    {:ok, %{players: [], board: [nil, nil, nil, nil, nil, nil, nil, nil, nil]}}
  end

  defp pid_to_symbol(players, pid) do
    players
    |> Enum.find_index(fn p -> p == pid end)
    |> Kernel.then(fn v ->
      case v do
        0 -> :o
        1 -> :x
        _ -> raise "Invalid index!"
      end
    end)
  end

  @impl true
  def handle_call({:choose, position}, {pid, _}, state) do
    player_symbol = pid_to_symbol(state.players, pid)
    active_player = Game.activePlayer(state.board)

    if player_symbol != active_player do
      {:reply, {:error, :not_your_turn}, state}
    else
      case Game.choose(state.board, position) do
        {:ok, board} ->
          state = state |> Map.put(:board, board) |> Map.put(:status, :other_turn)

          case Game.winner?(board) do
            nil -> GenServer.cast(self(), :activate_player)
            _ -> GenServer.cast(self(), :announce_winner)
          end

          {:reply, {:ok, state}, state}

        :error ->
          {:reply, {:error, "already chosen"}, state}
      end
    end
  end

  def handle_call(:join, {pid, _}, state) do
    IO.inspect(pid, label: "Handling join for player")
    IO.inspect(state)

    if Enum.count(state.players) < 2 do
      players = state.players ++ [pid]
      state = Map.put(state, :players, players)

      case players do
        [_, _] ->
          GenServer.cast(self(), :activate_player)
          nil

        _ ->
          nil
      end

      IO.inspect(pid_to_symbol(state.players, pid), label: "Assigned symbol")
      {:reply, {:ok, %{status: :waiting, my_symbol: pid_to_symbol(state.players, pid)}}, state}
    else
      {:reply, {:error, "game is full"}, state}
    end
  end

  def handle_cast(:activate_player, state) do
    board = state.board
    players = state.players
    active_player = Game.activePlayer(board)

    {active, waiting} =
      if pid_to_symbol(state.players, players |> Enum.at(0)) == active_player do
        {players |> Enum.at(0), players |> Enum.at(1)}
      else
        {players |> Enum.at(1), players |> Enum.at(0)}
      end

    send(active, {:ok, %{status: :your_turn, board: state.board}})
    send(waiting, {:ok, %{status: :other_turn, board: state.board}})

    {:noreply, state}
  end

  def handle_cast(:restart, state) do
    players = state.players |> Enum.reverse()
    board = [nil, nil, nil, nil, nil, nil, nil, nil, nil]
    GenServer.cast(self(),:activate_player)
    {:noreply, %{players: players, board: board}}
  end

  def handle_cast(:announce_winner, state) do
    case Game.winner?(state.board) do
      nil ->
        nil
      winner ->
        {winner, loser} =
          case winner do
            :x -> {state.players |> Enum.at(0), state.players |> Enum.at(1)}
            :o -> {state.players |> Enum.at(1), state.players |> Enum.at(0)}
          end

        send(winner, {:ok, %{status: :you_lost, board: state.board}})
        send(loser, {:ok, %{status: :you_won, board: state.board}})
    end

    {:noreply, state}
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
