defmodule CalculatorWeb.CalculatorLive do
  use CalculatorWeb, :live_view

  @topic "calculator"
  @sync_topic "calculator_sync"
  @region_interval 5000 # Update regions every 5 seconds

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Calculator.PubSub, @topic)
      Phoenix.PubSub.subscribe(Calculator.PubSub, @sync_topic)
      :timer.send_interval(@region_interval, :update_regions)
      send(self(), :update_regions)
    end

    {:ok, assign(socket,
      display: "0",
      formula: "",
      first_number: nil,
      operation: nil,
      next_clear: false,
      regions: [],
      client_latency: nil
    )}
  end

  @impl true
  def handle_event("keydown", %{"key" => key}, socket) do
    case key do
      key when key in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "."] ->
        handle_event("digit", %{"digit" => key}, socket)

      "+" -> handle_event("operation", %{"op" => "+"}, socket)
      "-" -> handle_event("operation", %{"op" => "-"}, socket)
      "*" -> handle_event("operation", %{"op" => "*"}, socket)
      "/" -> handle_event("operation", %{"op" => "/"}, socket)
      "x" -> handle_event("operation", %{"op" => "*"}, socket)

      key when key in ["Enter", "="] -> handle_event("calculate", %{}, socket)
      key when key in ["Escape", "c", "C"] -> handle_event("clear", %{}, socket)

      "Backspace" ->
        case socket.assigns.display do
          "0" -> {:noreply, socket}
          display when byte_size(display) == 1 ->
            new_state = %{display: "0", next_clear: false}
            broadcast_change(new_state)
            {:noreply, assign(socket, new_state)}
          display ->
            new_display = String.slice(display, 0..-2)
            new_state = %{display: new_display, next_clear: false}
            broadcast_change(new_state)
            {:noreply, assign(socket, new_state)}
        end

      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("digit", %{"digit" => digit}, %{assigns: %{display: display, next_clear: next_clear}} = socket) do
    new_display = if next_clear or display == "0", do: digit, else: display <> digit
    broadcast_change(%{display: new_display, next_clear: false})
    {:noreply, assign(socket, display: new_display, next_clear: false)}
  end

  @impl true
  def handle_event("operation", %{"op" => op}, %{assigns: %{display: display, first_number: first, operation: prev_op, formula: formula}} = socket) do
    operator_symbol = get_operator_symbol(op)
    current = parse_number(display)

    {new_number, new_formula} = if first != nil and prev_op != nil do
      # If we have a previous operation, calculate it first
      result = calculate(first, current, prev_op) |> format_result()
      {parse_number(result), "#{formula} #{display} #{operator_symbol}"}
    else
      {current, "#{display} #{operator_symbol}"}
    end

    new_state = %{
      first_number: new_number,
      operation: op,
      next_clear: true,
      formula: new_formula,
      display: format_result(new_number)
    }
    broadcast_change(new_state)
    {:noreply, assign(socket, new_state)}
  end

  @impl true
  def handle_event("calculate", _params, %{assigns: %{display: display, first_number: first, operation: op, formula: formula}} = socket) when not is_nil(first) and not is_nil(op) do
    second = parse_number(display)
    result = calculate(first, second, op) |> format_result()

    new_state = %{
      display: result,
      formula: "#{formula} #{display} = #{result}",
      first_number: nil,
      operation: nil,
      next_clear: true
    }
    broadcast_change(new_state)
    {:noreply, assign(socket, new_state)}
  end

  @impl true
  def handle_event("clear", _params, socket) do
    new_state = %{
      display: "0",
      formula: "",
      first_number: nil,
      operation: nil,
      next_clear: false
    }
    broadcast_change(new_state)
    {:noreply, assign(socket, new_state)}
  end

  @impl true
  def handle_event("ping", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("latency", %{"ms" => ms}, socket) do
    {:noreply, assign(socket, client_latency: ms)}
  end

  @impl true
  def handle_info(:update_regions, socket) do
    regions = Calculator.Regions.connected_nodes_with_ping()
    {:noreply, assign(socket, regions: regions)}
  end

  # Handle state request from new clients
  def handle_info({:request_current_state, _requester_pid}, %{assigns: assigns} = socket) do
    if assigns.display != "0" or assigns.first_number != nil do
      current_state = %{
        display: assigns.display,
        formula: assigns.formula,
        first_number: assigns.first_number,
        operation: assigns.operation,
        next_clear: assigns.next_clear
      }
      Phoenix.PubSub.broadcast(Calculator.PubSub, @sync_topic, {:current_state, current_state})
    end
    {:noreply, socket}
  end

  # Receive current state as a new client
  def handle_info({:current_state, state}, socket) do
    {:noreply, assign(socket, state)}
  end

  def handle_info({:calculator_update, new_state}, socket) do
    {:noreply, assign(socket, new_state)}
  end

  defp broadcast_change(new_state) do
    Phoenix.PubSub.broadcast(Calculator.PubSub, @topic, {:calculator_update, new_state})
  end

  defp get_operator_symbol(op) do
    case op do
      "+" -> "+"
      "-" -> "-"
      "*" -> "×"
      "/" -> "÷"
    end
  end

  defp calculate(first, second, op) do
    case op do
      "+" -> first + second
      "-" -> first - second
      "*" -> first * second
      "/" -> first / second
    end
  end

  defp parse_number(string) do
    case Float.parse(string) do
      {number, _} -> number
      :error -> String.to_integer(string)
    end
  end

  defp format_result(number) when is_binary(number), do: number
  defp format_result(number) do
    if number == trunc(number) do
      Integer.to_string(trunc(number))
    else
      Float.to_string(number)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="min-h-screen bg-black md:bg-black flex flex-col">
      <div class="flex-1 bg-zinc-900 md:bg-black flex items-center justify-center">
        <div id="calculator" class="w-full max-w-md aspect-[3/4] md:aspect-auto md:w-[380px] md:h-[600px]">
          <div class="h-full flex flex-col p-2 md:p-4 md:bg-zinc-900 md:rounded-2xl">
            <div class="flex flex-col items-end justify-end mb-4">
              <output class="text-white text-5xl md:text-6xl"><%= @display %></output>
              <output class="text-zinc-500 text-lg py-2"><%= if @formula == "", do: "waiting...", else: @formula %></output>
            </div>

            <div class="grid grid-cols-4 gap-[3%] aspect-square h-[75%]" phx-window-keydown="keydown">
              <button phx-click="clear" class="aspect-square text-xl bg-zinc-800 rounded-full hover:bg-zinc-700 flex items-center justify-center">C</button>
              <button phx-click="operation" phx-value-op="+/-" class="aspect-square text-xl bg-zinc-800 rounded-full hover:bg-zinc-700 flex items-center justify-center">+/-</button>
              <button phx-click="operation" phx-value-op="%" class="aspect-square text-xl bg-zinc-800 rounded-full hover:bg-zinc-700 flex items-center justify-center">%</button>
              <button phx-click="operation" phx-value-op="/" class="aspect-square text-xl bg-orange-500 rounded-full hover:bg-orange-400 flex items-center justify-center">÷</button>

              <button phx-click="digit" phx-value-digit="7" class="aspect-square text-xl bg-zinc-800 rounded-full hover:bg-zinc-700 flex items-center justify-center">7</button>
              <button phx-click="digit" phx-value-digit="8" class="aspect-square text-xl bg-zinc-800 rounded-full hover:bg-zinc-700 flex items-center justify-center">8</button>
              <button phx-click="digit" phx-value-digit="9" class="aspect-square text-xl bg-zinc-800 rounded-full hover:bg-zinc-700 flex items-center justify-center">9</button>
              <button phx-click="operation" phx-value-op="*" class="aspect-square text-xl bg-orange-500 rounded-full hover:bg-orange-400 flex items-center justify-center">×</button>

              <button phx-click="digit" phx-value-digit="4" class="aspect-square text-xl bg-zinc-800 rounded-full hover:bg-zinc-700 flex items-center justify-center">4</button>
              <button phx-click="digit" phx-value-digit="5" class="aspect-square text-xl bg-zinc-800 rounded-full hover:bg-zinc-700 flex items-center justify-center">5</button>
              <button phx-click="digit" phx-value-digit="6" class="aspect-square text-xl bg-zinc-800 rounded-full hover:bg-zinc-700 flex items-center justify-center">6</button>
              <button phx-click="operation" phx-value-op="-" class="aspect-square text-xl bg-orange-500 rounded-full hover:bg-orange-400 flex items-center justify-center">−</button>

              <button phx-click="digit" phx-value-digit="1" class="aspect-square text-xl bg-zinc-800 rounded-full hover:bg-zinc-700 flex items-center justify-center">1</button>
              <button phx-click="digit" phx-value-digit="2" class="aspect-square text-xl bg-zinc-800 rounded-full hover:bg-zinc-700 flex items-center justify-center">2</button>
              <button phx-click="digit" phx-value-digit="3" class="aspect-square text-xl bg-zinc-800 rounded-full hover:bg-zinc-700 flex items-center justify-center">3</button>
              <button phx-click="operation" phx-value-op="+" class="aspect-square text-xl bg-orange-500 rounded-full hover:bg-orange-400 flex items-center justify-center">+</button>

              <button phx-click="digit" phx-value-digit="0" class="col-span-2 text-xl bg-zinc-800 rounded-full hover:bg-zinc-700 flex items-center ps-[38%]">0</button>
              <button phx-click="digit" phx-value-digit="." class="aspect-square text-xl bg-zinc-800 rounded-full hover:bg-zinc-700 flex items-center justify-center">.</button>
              <button phx-click="calculate" class="aspect-square text-xl bg-orange-500 rounded-full hover:bg-orange-400 flex items-center justify-center">=</button>
            </div>
          </div>
        </div>
      </div>

      <div id="status-bar" phx-hook="Ping" class="fixed bottom-0 left-0 right-0 p-2 bg-fuchsia-900/30 backdrop-blur-sm border-t border-fuchsia-800/20">
        <div class="max-w-4xl mx-auto px-4 text-sm text-zinc-400 flex items-center">
          <div class="flex items-center gap-2">
            <%= Calculator.Regions.get_flag(System.get_env("FLY_REGION")) %>
            <span><%= System.get_env("FLY_REGION") || "LOCAL" %></span>
            <span><%= if @client_latency, do: "#{@client_latency}ms", else: "-" %></span>
          </div>

          <div class="flex-1 flex justify-end">
            <div class="relative max-w-[50%]">
              <div class="overflow-x-auto flex gap-6 scrollbar-none">
                <%= if Enum.empty?(@regions) do %>
                  <span class="flex items-center gap-2 shrink-0">
                    🏁
                    <span>DEV</span>
                    <span>150ms</span>
                  </span>
                <% else %>
                  <%= for region <- @regions do %>
                    <span class="flex items-center gap-2 shrink-0">
                      <%= region.flag %>
                      <span><%= region.region %></span>
                      <span><%= region.ping_ms %>ms</span>
                    </span>
                  <% end %>
                <% end %>
              </div>
              <div class="absolute right-0 top-0 bottom-0 w-8 bg-gradient-to-l from-fuchsia-900/30 to-transparent pointer-events-none"></div>
            </div>
          </div>
        </div>
      </div>
    </main>
    """
  end
end
