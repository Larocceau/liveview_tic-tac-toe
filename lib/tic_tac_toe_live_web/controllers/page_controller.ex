defmodule TicTacToeLiveWeb.PageController do
  use TicTacToeLiveWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
