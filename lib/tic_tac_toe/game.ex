  defmodule TicTacToe.Game do
    def result?(board) do
      case winner?(board) do
        nil ->
          if Enum.all?(board) do
            :draw
          else
            nil
          end

        winner ->
          {:win, winner}
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
