defmodule TicTacToeLive.Repo do
  use Ecto.Repo,
    otp_app: :tic_tac_toe_live,
    adapter: Ecto.Adapters.Postgres
end
