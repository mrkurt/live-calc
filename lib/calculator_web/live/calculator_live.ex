defmodule CalculatorWeb.CalculatorLive do
  use CalculatorWeb, :live_view

  @topic "calculator"
  @sync_topic "calculator_sync"

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Calculator.PubSub, @topic)
      # Request current state when a new client connects
      Phoenix.PubSub.broadcast(Calculator.PubSub, @sync_topic, {:request_current_state, self()})
      Phoenix.PubSub.subscribe(Calculator.PubSub, @sync_topic)
    end

    {:ok, assign(socket,
      display: "0",
      formula: "",
      first_number: nil,
      operation: nil,
      next_clear: false
    )}
  end

  # Handle state request from new clients
  def handle_info({:request_current_state, requester_pid}, %{assigns: assigns} = socket) do
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

  # Handle keyboard input
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

  def handle_event("digit", %{"digit" => digit}, %{assigns: %{display: display, next_clear: next_clear}} = socket) do
    new_display = if next_clear or display == "0", do: digit, else: display <> digit
    broadcast_change(%{display: new_display, next_clear: false})
    {:noreply, assign(socket, display: new_display, next_clear: false)}
  end

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

  def render(assigns) do
    ~H"""
    <div class="calculator-container" phx-window-keydown="keydown">
      <div class="display-container">
        <div class="formula"><%= @formula %></div>
        <div class="display"><%= @display %></div>
      </div>
      <div class="keypad">
        <button phx-click="digit" phx-value-digit="7">7</button>
        <button phx-click="digit" phx-value-digit="8">8</button>
        <button phx-click="digit" phx-value-digit="9">9</button>
        <button class={"operator #{if @operation == "/", do: "active"}"} phx-click="operation" phx-value-op="/">/</button>

        <button phx-click="digit" phx-value-digit="4">4</button>
        <button phx-click="digit" phx-value-digit="5">5</button>
        <button phx-click="digit" phx-value-digit="6">6</button>
        <button class={"operator #{if @operation == "*", do: "active"}"} phx-click="operation" phx-value-op="*">×</button>

        <button phx-click="digit" phx-value-digit="1">1</button>
        <button phx-click="digit" phx-value-digit="2">2</button>
        <button phx-click="digit" phx-value-digit="3">3</button>
        <button class={"operator #{if @operation == "-", do: "active"}"} phx-click="operation" phx-value-op="-">-</button>

        <button phx-click="digit" phx-value-digit="0">0</button>
        <button phx-click="digit" phx-value-digit=".">.</button>
        <button class="equals" phx-click="calculate">=</button>
        <button class={"operator #{if @operation == "+", do: "active"}"} phx-click="operation" phx-value-op="+">+</button>

        <button class="clear" phx-click="clear">C</button>
      </div>
    </div>
    """
  end
end
