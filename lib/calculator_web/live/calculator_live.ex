defmodule CalculatorWeb.CalculatorLive do
  use CalculatorWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      display: "0",
      first_number: nil,
      operation: nil,
      next_clear: false
    )}
  end

  def handle_event("digit", %{"digit" => digit}, %{assigns: %{display: display, next_clear: next_clear}} = socket) do
    new_display = if next_clear or display == "0", do: digit, else: display <> digit
    {:noreply, assign(socket, display: new_display, next_clear: false)}
  end

  def handle_event("operation", %{"op" => op}, %{assigns: %{display: display}} = socket) do
    {:noreply, assign(socket,
      first_number: parse_number(display),
      operation: op,
      next_clear: true
    )}
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

    {:noreply, assign(socket,
      display: result,
      first_number: nil,
      operation: nil,
      next_clear: true
    )}
  end

  def handle_event("clear", _params, socket) do
    {:noreply, assign(socket,
      display: "0",
      first_number: nil,
      operation: nil,
      next_clear: false
    )}
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
