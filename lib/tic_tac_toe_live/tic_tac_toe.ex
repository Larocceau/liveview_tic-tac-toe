defmodule TicTacToe do
  use GenServer

  @moduledoc """
  Documentation for `TicTacToe`.
  """

  defmodule Game do

    def result?(board) do
      case winner?(board) do
        nil ->
          if Enum.all?(board) do
            :draw
          else
            nil
          end
        winner -> {:win, winner}
      end
    end

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

  def start_link(code, opts \\ Keyword.new()) do
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
    |> Enum.find_value(fn {symbol, p} -> p == pid && symbol end)
  end

  defp player_and_other(symbol, players) do
    one = players[symbol]
    other = players |> Enum.find_value(fn {s, pid} -> s != symbol && pid end)

    {one, other}
  end

  defp activate_players(state) do
    board = state.board
    players = state.players

    {active, waiting} =
      Game.activePlayer(board)
      |> player_and_other(players)


    send(active, {:ok, %{status: :your_turn, board: state.board}})
    send(waiting, {:ok, %{status: :other_turn, board: state.board}})

    state
  end

  defp announce_result(state, result) do
    case result do
      :draw ->
        state.players
        |> Enum.map(&send(&1, {:ok, %{status: :draw, board: state.board}}))
      {:win, winner} ->
        {winner, loser} = player_and_other(winner, state.players)

        send(loser, {:ok, %{status: :you_lost, board: state.board}})
        send(winner, {:ok, %{status: :you_won, board: state.board}})
    end

    state
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

          state =
            case Game.result?(board) do
              nil -> activate_players(state)
              result-> announce_result(state, result)
            end

          {:reply, {:ok, state}, state}

        :error ->
          {:reply, {:error, "already chosen"}, state}
      end
    end
  end

  def handle_call(:join, {pid, _}, state) do
    players =
      case state.players do
          %{x: _, o: _} -> nil
          %{x: _} = players -> Map.put(players, :o, pid)
          _ -> %{x: pid}
      end

    case players do
    nil -> {:reply, {:error, :game_full, state}}
    players ->
      state =
        state
        |> Map.put(:players, players)

      with %{x: _, o: _} <- players do activate_players(state) end

      {:reply, {:ok, %{status: :waiting, my_symbol: pid_to_symbol(state.players, pid)}}, state}

    end
  end

  def handle_cast(:restart, state) do
    state =
      state
      |> Map.put(:players, state.players |> Enum.reverse())
      |> Map.put(:board, [nil, nil, nil, nil, nil, nil, nil, nil, nil])
      |> activate_players()

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
