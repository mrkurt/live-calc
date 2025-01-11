defmodule CalculatorWeb.HealthController do
  use CalculatorWeb, :controller

  def check(conn, _params) do
    send_resp(conn, 200, "")
  end
end
