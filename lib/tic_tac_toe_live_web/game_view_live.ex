defmodule TicTacToeLiveWeb.GameViewLive do
  use TicTacToeLiveWeb, :live_view

  def handle_server_message(message, socket) do
    case message do
      {:ok, state } ->
        socket
        |> assign(:board, state.board)
        |> assign(:status, state.status)
      {:error, message} ->
        socket
        |> assign(:error, message)

    end
  end

  def handle_info(msg, socket) do
    socket =
      handle_server_message(msg, socket)
    {:noreply, socket}
  end

  def render_board(assigns) do
    ~H"""
    <table>
      <%= for row <- 0..2 do %>
        <tr>
        <%= for col <- 0..2 do %>
          <td><button></button></td>
        <% end %>
        </tr>

      <% end %>
    </table>
    """
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    case Map.get(assigns, :error) do
      nil ->
        ~H"""
        <h1>This is the game view!</h1>
        {render_board(assigns)}
        {case Map.get(assigns, :status) do
          :your_turn -> "It's your turn"
          :other_turn -> "It's your opponent's turn"
          _ -> "Not started yet!"
        end
        }
        <button phx-click=""></button>
        """

      _ ->
        ~H"""
        <h1>an error occured!</h1>
        {@error}
        """
    end
  end

  def mount(_, _, socket) do
    socket =
      if connected?(socket) do
        message = TicTacToe.join()
        handle_server_message(message, socket)
      else
        socket
      end

    {:ok, socket}
  end

  def handle_event(event, unsigned_params, socket) do
    raise "TO DO"
  end
end
