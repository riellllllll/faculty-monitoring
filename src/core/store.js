export const store = {
  user: null,
  setUser(u) { this.user = u; },
  clear() { this.user = null; },

  /** True when the signed-in user holds the capability (or any of an array). */
  hasCap(cap) {
    const caps = this.user?.capabilities || [];
    return Array.isArray(cap) ? cap.some(c => caps.includes(c)) : caps.includes(cap);
  },

  hasRole(...roles) {
    return !!this.user && roles.some(r => (this.user.roles || []).includes(r));
  },
};
