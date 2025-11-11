defmodule TicTacToeWeb.GameLive do
  use TicTacToeWeb, :live_view

  def connect(join_code, socket) do
    code =
      case join_code do
        nil ->
          code = UUID.uuid1()
          {:ok, _} = TicTacToe.GameServer.start_link(code)
          code

        code ->
          code
      end

    case TicTacToe.GameServer.join(code) do
      {:ok, state} ->
        socket
        |> assign(:my_symbol, state.my_symbol)
        |> assign(:status, state.status)
        |> assign(:game_id, code)

      {:error, e} ->
        socket
        |> assign(:error, e)
    end
  end

  @impl true
  def mount(params, _session, socket) do
    join_code = params["join_code"]

    socket =
      socket
      |> assign_new(:error, fn _ -> nil end)
      |> assign_new(:game_id, fn _ -> nil end)
      |> assign_new(:status, fn _ -> :connecting end)
      |> assign_new(:my_symbol, fn _ -> nil end)
      |> assign_new(:board, fn _ -> nil end)

    socket =
      if not connected?(socket) do
        socket
      else
        connect(join_code, socket)
      end

    {:ok, socket}
  end

  @impl true
  def handle_info(message, socket) do
    {:noreply, handle_server_message(message, socket)}
  end

  defp handle_server_message({:ok, state}, socket) do
    status = Map.get(state, :status, :pending)

    socket
    |> assign(:error, nil)
    |> assign(:board, Map.get(state, :board, socket.assigns[:board]))
    |> assign(:status, status)
    |> assign(:my_symbol, Map.get(state, :my_symbol, socket.assigns[:my_symbol]))
  end

  defp handle_server_message({:error, reason}, socket) do
    assign(socket, :error, reason)
  end

  defp handle_server_message(_other, socket) do
    socket
  end

  @impl true
  def handle_event("choose", params, socket) do
    TicTacToe.GameServer.choose(socket.assigns.game_id, params["index"] |> String.to_integer())
    {:noreply, socket}
  end

  def handle_event("restart", _, socket) do
    TicTacToe.GameServer.restart(socket.assigns.game_id)
    {:noreply, socket}
  end

  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section class="mx-auto flex max-w-xl flex-col gap-6 p-8">
        <header class="space-y-2 text-center">
          <h1 class="text-3xl font-semibold text-zinc-900">Tic Tac Toe</h1>
          <%= if @game_id && @status == :waiting do %>
            <p class="text-xs text-zinc-400">Share this code to invite a friend: {@game_id}</p>
            <div class="flex flex-wrap justify-center gap-3">
              <.link
                class="rounded-md bg-zinc-900 px-4 py-2 text-sm font-semibold text-white transition hover:bg-zinc-700 focus:outline-none focus:ring-2 focus:ring-zinc-500 focus:ring-offset-2"
                href={~p"/game?join_code=#{@game_id}"}
                target="_blank"
                rel="noopener"
              >
                Open Game In New Tab
              </.link>
            </div>
          <% end %>
        </header>

        <%= if @error do %>
          <.error_banner message={@error} />
        <% else %>
          <.status_badge status={@status} />
          <%= if not is_nil(Map.get(assigns, :board)&& Map.get(assigns, :my_symbol)) do %>
            <.board board={@board} my_symbol={@my_symbol} status={@status} />
          <% end %>
          <%= if Enum.member?([:you_won, :you_lost, :draw], @status) do %>
            <button phx-click="restart" class="btn">Restart</button>
          <% end %>
        <% end %>
      </section>
    </Layouts.app>
    """
  end

  attr :message, :string, required: true

  defp error_banner(assigns) do
    ~H"""
    <div class="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
      {@message}
    </div>
    """
  end

  attr :status, :atom, required: true

  defp status_badge(assigns) do
    assigns = assign(assigns, :label, status_message(assigns.status))

    ~H"""
    <p class="w-full rounded-md bg-zinc-100 px-3 py-2 text-center text-sm font-medium text-zinc-700">
      {@label}
    </p>
    """
  end

  defp status_message(:you_won), do: "You won!"
  defp status_message(:you_lost), do: "You lost!"
  defp status_message(:your_turn), do: "It's your turn."
  defp status_message(:draw), do: "It's a draw!"
  defp status_message(:other_turn), do: "Waiting for your opponent..."
  defp status_message(:pending), do: "Game underway."
  defp status_message(:waiting), do: "Waiting for another player to join."
  defp status_message(_), do: "Preparing the game..."

  attr :board, :list, required: true
  attr :my_symbol, :atom, required: true

  defp board(assigns) do
    assigns =
      assign(
        assigns,
        :placeholder,
        case assigns.status do
          :your_turn -> assigns.my_symbol
          _ -> ""
        end
      )

    ~H"""
    <table class="w-full table-fixed border-separate border-spacing-2">
      <tbody>
        <%= for row <- 0..2 do %>
          <tr>
            <%= for col <- 0..2 do %>
              <% idx = board_index(row, col) %>
              <td class="aspect-square">
                <button
                  id={"cell-#{idx}"}
                  type="button"
                  phx-click="choose"
                  class="btn"
                  phx-value-index={idx}
                  disabled={not is_nil(Enum.at(@board, idx))}
                >
                  {cell_label(Enum.at(@board, idx) || @placeholder)}
                </button>
              </td>
            <% end %>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end

  defp board_index(row, col), do: row * 3 + col

  defp cell_label(nil), do: ""
  defp cell_label(player) when is_atom(player), do: player |> Atom.to_string() |> String.upcase()
  defp cell_label(player), do: to_string(player)
end
