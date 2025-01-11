const Hooks = {
  Ping: {
    pingCount: 0,
    isPinging: false,
    pingHistory: [],
    normalInterval: 5000,
    fastInterval: 1000,

    mounted() {
      // Wait 3s before first ping
      setTimeout(() => {
        this.measureLatency()
        this.scheduleNextPing()
      }, 3000)
    },

    destroyed() {
      if (this.timeout) {
        clearTimeout(this.timeout)
      }
    },

    scheduleNextPing() {
      if (this.timeout) {
        clearTimeout(this.timeout)
      }

      // Calculate average of last 10 pings
      const recentPings = this.pingHistory.slice(-10)
      const avgPing = recentPings.length > 0 
        ? recentPings.reduce((a, b) => a + b, 0) / recentPings.length 
        : 0
      
      // If latest ping is more than 2x the average, use fast interval
      const latestPing = this.pingHistory[this.pingHistory.length - 1] || 0
      const interval = (avgPing > 0 && latestPing > avgPing * 2) 
        ? this.fastInterval 
        : this.normalInterval

      this.timeout = setTimeout(() => this.measureLatency(), interval)
    },

    measureLatency() {
      if (this.isPinging) return;
      this.isPinging = true;
      const startTime = performance.now();
      this.pushEvent("ping", {}, () => {
        const latency = Math.round(performance.now() - startTime);
        this.pingHistory.push(latency);
        // Keep only the last 10 measurements
        if (this.pingHistory.length > 10) {
          this.pingHistory = this.pingHistory.slice(-10);
        }
        this.pushEvent("latency", { ms: latency });
        this.isPinging = false;
        this.scheduleNextPing();
      });
    }
  }
}

export default Hooks 