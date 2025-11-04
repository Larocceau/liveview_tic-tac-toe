defmodule TicTacToe.GameServer do
  use GenServer

  alias TicTacToe.Game

  @moduledoc """
  Documentation for `TicTacToe`.
  """

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
    {:ok, %{players: %{}, board: [nil, nil, nil, nil, nil, nil, nil, nil, nil]}}
  end

  defp pid_to_symbol(players, pid) do
    players
    |> Enum.find_value(fn {symbol, p} -> p == pid && symbol end)
  end

  defp activate_players(%{players: %{x: x_pid, o: o_pid}, board: board} = state) do
    {active, waiting} =
      case Game.activePlayer(board) do
        :x -> {x_pid, o_pid}
        :o -> {o_pid, x_pid}
      end

    send(active, {:ok, %{status: :your_turn, board: board}})
    send(waiting, {:ok, %{status: :other_turn, board: board}})

    state
  end

  defp announce_result(%{players: %{x: x_pid, o: o_pid}} = state, result) do
    case result do
      :draw ->
        state.players
        |> Enum.each(&send(&1, {:ok, %{status: :draw, board: state.board}}))

      {:win, winner} ->
        {winner, loser} =
          case winner do
            :x -> {x_pid, o_pid}
            :o -> {o_pid, x_pid}
          end

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
              result -> announce_result(state, result)
            end

          {:reply, {:ok, state}, state}

        :error ->
          {:reply, {:error, "already chosen"}, state}
      end
    end
  end

  def handle_call(:join, {pid, _}, state) do
    case state.players do
      %{x: _, o: _} ->
        {:reply, {:error, :game_full, state}}

      %{x: _} = players ->
        state = %{state | players: Map.put(players, :o, pid)} |> activate_players()
        {:reply, {:ok, %{status: :waiting, my_symbol: pid_to_symbol(state.players, pid)}}, state}

      %{} ->
        state = %{state | players: %{x: pid}}
        {:reply, {:ok, %{status: :waiting, my_symbol: pid_to_symbol(state.players, pid)}}, state}
    end
  end

  def handle_cast(:restart, %{players: %{x: x_pid, o: o_pid}} = state) do
    state =
      state
      |> Map.put(:players, %{x: o_pid, o: x_pid})
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
