# LiveCalc

A real-time collaborative calculator built with Phoenix LiveView. Multiple users can interact with the calculator simultaneously, with all operations and state changes synchronized in real-time across all connected clients.

## Features

- Basic arithmetic operations (+, -, ×, ÷)
- Real-time synchronization between all connected users
- Formula display showing the current calculation
- Chained operations (e.g., "9 × 6 + 4 ÷ 12")
- Keyboard support
- Responsive design
- No database required

## Local Development

### Prerequisites

- Elixir 1.14 or later
- Erlang 25 or later
- Node.js 18 or later

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/mrkurt/live-calc.git
   cd live-calc
   ```

2. Install dependencies:
   ```bash
   mix deps.get
   cd assets && npm install && cd ..
   ```

3. Start the Phoenix server:
   ```bash
   mix phx.server
   ```

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

### Keyboard Shortcuts

- Numbers: `0-9` and `.` for decimal point
- Operators: `+`, `-`, `*` or `x`, `/`
- Calculate: `Enter` or `=`
- Clear: `Escape`, `c`, or `C`
- Delete: `Backspace`

## Deployment on Fly.io

### Prerequisites

- [Fly.io CLI](https://fly.io/docs/hands-on/install-flyctl/) installed
- Fly.io account (sign up at [fly.io](https://fly.io))

### Deployment Steps

1. Log in to Fly.io:
   ```bash
   fly auth login
   ```

2. Launch the app (first time only):
   ```bash
   fly launch
   ```
   - Choose a unique app name
   - Choose the region closest to you
   - Say no to database setup
   - Say no to deploy now

3. Update the generated `fly.toml`:
   ```toml
   [env]
   PHX_HOST = "your-app-name.fly.dev"
   PORT = "8080"
   ```

4. Deploy the app:
   ```bash
   fly deploy
   ```

5. Visit your app:
   ```bash
   fly open
   ```

### Setting Up Clustering

LiveCalc uses distributed Erlang for clustering on Fly.io, which enables real-time synchronization across multiple regions. Here's how to set it up:

1. Ensure you have the `dns_cluster` dependency in `mix.exs`:
   ```elixir
   {:dns_cluster, "~> 0.1.1"}
   ```

2. Configure your application for clustering in `lib/calculator/application.ex`:
   ```elixir
   children = [
     CalculatorWeb.Telemetry,
     {DNSCluster, query: Application.get_env(:calculator, :dns_cluster_query) || :ignore},
     {Phoenix.PubSub, name: Calculator.PubSub},
     # ... other children
     CalculatorWeb.Endpoint
   ]
   ```

3. Set up node naming in `rel/env.sh.eex`:
   ```bash
   #!/bin/sh
   export ERL_AFLAGS="-proto_dist inet6_tcp"
   export ECTO_IPV6="true"
   export DNS_CLUSTER_QUERY="${FLY_APP_NAME}.internal"
   export RELEASE_DISTRIBUTION="name"
   export RELEASE_NODE="${FLY_APP_NAME}@${FLY_PRIVATE_IP}"
   ```

4. Configure runtime settings in `config/runtime.exs`:
   ```elixir
   app_name = System.get_env("FLY_APP_NAME") ||
     raise "FLY_APP_NAME not available"

   config :calculator, :dns_cluster_query, "#{app_name}.internal"
   ```

5. Enable clustering in `fly.toml`:
   ```toml
   [env]
   PHX_HOST = "your-app-name.fly.dev"
   PORT = "8080"
   RELEASE_COOKIE = "your-app-name-cookie"
   DNS_CLUSTER_QUERY = "your-app-name.internal"

   [http_service]
   internal_port = 8080
   force_https = true
   auto_stop_machines = true
   auto_start_machines = true
   min_machines_running = 1  # Important: keep at least one machine running
   ```

6. Deploy the updated configuration:
   ```bash
   fly deploy
   ```

7. Scale to multiple regions:
   ```bash
   fly scale count 6 --region atl,lax,lhr,syd,sin,yyz
   ```

8. Start all machines and verify clustering:
   ```bash
   # Start all machines
   fly machines list -q | xargs -n1 fly machines start

   # Wait a moment for machines to connect, then verify clustering
   fly ssh console -C "bin/calculator rpc \"IO.inspect(Node.list())\""
   ```
   This should show a list of connected nodes across your regions.

### Subsequent Deployments

After making changes, simply run:
```bash
fly deploy
```

## Architecture

- Built with Phoenix LiveView for real-time functionality
- Uses Phoenix PubSub for state synchronization
- No database required - all state is managed in memory
- TailwindCSS for styling

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request