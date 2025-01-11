const ScrollIndicator = {
  mounted() {
    this.updateScrollIndicator();
    this.el.addEventListener("scroll", () => this.updateScrollIndicator());
    window.addEventListener("resize", () => this.updateScrollIndicator());
  },

  updateScrollIndicator() {
    const indicator = document.getElementById("region-scroll-indicator");
    if (!indicator) return;

    const hasScroll = this.el.scrollWidth > this.el.clientWidth;
    indicator.classList.toggle("hidden", !hasScroll);
  }
};

export default ScrollIndicator; 