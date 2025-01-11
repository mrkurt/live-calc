defmodule Calculator.Regions do
  use GenServer

  @region_flags %{
    # Europe
    "ams" => "🇳🇱", # Amsterdam, Netherlands
    "arn" => "🇸🇪", # Stockholm, Sweden
    "cdg" => "🇫🇷", # Paris, France
    "fra" => "🇩🇪", # Frankfurt, Germany
    "lhr" => "🇬🇧", # London, United Kingdom
    "mad" => "🇪🇸", # Madrid, Spain
    "otp" => "🇷🇴", # Bucharest, Romania
    "waw" => "🇵🇱", # Warsaw, Poland

    # North America
    "atl" => "🇺🇸", # Atlanta, USA
    "bos" => "🇺🇸", # Boston, USA
    "den" => "🇺🇸", # Denver, USA
    "dfw" => "🇺🇸", # Dallas, USA
    "ewr" => "🇺🇸", # Secaucus, USA
    "iad" => "🇺🇸", # Ashburn, USA
    "lax" => "🇺🇸", # Los Angeles, USA
    "mia" => "🇺🇸", # Miami, USA
    "ord" => "🇺🇸", # Chicago, USA
    "phx" => "🇺🇸", # Phoenix, USA
    "sea" => "🇺🇸", # Seattle, USA
    "sjc" => "🇺🇸", # San Jose, USA
    "yul" => "🇨🇦", # Montreal, Canada
    "yyz" => "🇨🇦", # Toronto, Canada

    # Asia & Pacific
    "hkg" => "🇭🇰", # Hong Kong
    "nrt" => "🇯🇵", # Tokyo, Japan
    "sin" => "🇸🇬", # Singapore
    "syd" => "🇦🇺", # Sydney, Australia
    "bom" => "🇮🇳", # Mumbai, India

    # Latin America
    "bog" => "🇨🇴", # Bogotá, Colombia
    "eze" => "🇦🇷", # Ezeiza, Argentina
    "gdl" => "🇲🇽", # Guadalajara, Mexico
    "gig" => "🇧🇷", # Rio de Janeiro, Brazil
    "gru" => "🇧🇷", # Sao Paulo, Brazil
    "qro" => "🇲🇽", # Querétaro, Mexico
    "scl" => "🇨🇱", # Santiago, Chile

    # Africa
    "jnb" => "🇿🇦"  # Johannesburg, South Africa
  }

  def get_flag(nil), do: "🌍"  # Return globe emoji for nil regions
  def get_flag(region) when is_binary(region) do
    region = String.downcase(region)
    Map.get(@region_flags, region, "🌍") # Default to globe if region not found
  end

  @doc """
  Returns a list of connected nodes with their ping times.
  Each entry is a map with:
  - node: the node name
  - region: the node's FLY_REGION environment variable (cached)
  - ping_ms: round trip time in milliseconds
  """

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  def get_client_info do
    {ping_ms, _} = :timer.tc(fn -> Node.ping(node()) end)
    region = System.get_env("FLY_REGION") || "local"

    %{
      region: String.upcase(region),
      ping_ms: Float.round(ping_ms / 1000, 2),
      flag: get_flag(region)
    }
  end

  def connected_nodes_with_ping do
    Node.list()
    |> Enum.map(fn node ->
      {ping_ms, _} = :timer.tc(fn -> Node.ping(node) end)
      region = GenServer.call(__MODULE__, {:get_region, node})

      %{
        node: node,
        region: String.upcase(region),
        ping_ms: Float.round(ping_ms / 1000, 2),
        flag: get_flag(region)
      }
    end)
    |> Enum.sort_by(& &1.ping_ms)
  end

  # Server callbacks

  def handle_call({:get_region, node}, _from, regions) do
    case Map.get(regions, node) do
      nil ->
        region = :rpc.call(node, System, :get_env, ["FLY_REGION"]) || "unknown"
        {:reply, region, Map.put(regions, node, region)}
      region ->
        {:reply, region, regions}
    end
  end
end
