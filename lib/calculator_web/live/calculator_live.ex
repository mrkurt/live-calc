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

  def handle_event("digit", %{"digit" => digit}, %{assigns: %{display: display, next_clear: next_clear}} = socket) do
    new_display = if next_clear or display == "0", do: digit, else: display <> digit
    broadcast_change(%{display: new_display, next_clear: false})
    {:noreply, assign(socket, display: new_display, next_clear: false)}
  end

  def handle_event("operation", %{"op" => op}, %{assigns: %{display: display}} = socket) do
    new_state = %{
      first_number: parse_number(display),
      operation: op,
      next_clear: true
    }
    broadcast_change(new_state)
    {:noreply, assign(socket, new_state)}
  end

  def handle_event("calculate", _params, %{assigns: %{display: display, first_number: first, operation: op}} = socket) when not is_nil(first) and not is_nil(op) do
    second = parse_number(display)
    result = case op do
      "+" -> Float.to_string(first + second)
      "-" -> Float.to_string(first - second)
      "*" -> Float.to_string(first * second)
      "/" -> Float.to_string(first / second)
    end
    |> format_result()

    new_state = %{
      display: result,
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
    <div class="calculator-container">
      <div class="display"><%= @display %></div>
      <div class="keypad">
        <button phx-click="digit" phx-value-digit="7">7</button>
        <button phx-click="digit" phx-value-digit="8">8</button>
        <button phx-click="digit" phx-value-digit="9">9</button>
        <button phx-click="operation" phx-value-op="/">/</button>

        <button phx-click="digit" phx-value-digit="4">4</button>
        <button phx-click="digit" phx-value-digit="5">5</button>
        <button phx-click="digit" phx-value-digit="6">6</button>
        <button phx-click="operation" phx-value-op="*">×</button>

        <button phx-click="digit" phx-value-digit="1">1</button>
        <button phx-click="digit" phx-value-digit="2">2</button>
        <button phx-click="digit" phx-value-digit="3">3</button>
        <button phx-click="operation" phx-value-op="-">-</button>

        <button phx-click="digit" phx-value-digit="0">0</button>
        <button phx-click="digit" phx-value-digit=".">.</button>
        <button phx-click="calculate">=</button>
        <button phx-click="operation" phx-value-op="+">+</button>

        <button class="clear" phx-click="clear">C</button>
      </div>
    </div>
    """
  end
end
