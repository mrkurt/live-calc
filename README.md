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
