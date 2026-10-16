/* Spices of Yash — progressive motion. Content is fully visible without this file;
   it only adds "js-ready" so reveal animations can run. Replaces the old inline
   scripts that the Content-Security-Policy (script-src 'self') blocked. */
(() => {
  "use strict";
  const root = document.documentElement;
  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // 1. Scroll reveal
  if ("IntersectionObserver" in window && !reduce) {
    root.classList.add("js-ready");
    const io = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-visible");
        io.unobserve(entry.target);
      });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.08 });
    const watch = () => document.querySelectorAll(".sy-reveal:not(.is-visible)").forEach(el => io.observe(el));
    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", watch); else watch();
    // Safety net: never leave content hidden (e.g. print, odd browsers).
    window.addEventListener("beforeprint", () => document.querySelectorAll(".sy-reveal").forEach(el => el.classList.add("is-visible")));
  }

  // 2. Header shadow once the page scrolls
  const onReady = fn => (document.readyState === "loading" ? document.addEventListener("DOMContentLoaded", fn) : fn());
  onReady(() => {
    const header = document.getElementById("site-header");
    if (header) {
      const update = () => header.classList.toggle("is-scrolled", window.scrollY > 8);
      update();
      window.addEventListener("scroll", update, { passive: true });
    }

    // 3. Gentle 3D tilt on the hero feature card (desktop pointers only)
    const card = document.getElementById("feature-card");
    const visual = card && card.closest(".hero__visual");
    const fine = window.matchMedia("(hover: hover) and (pointer: fine) and (min-width: 901px)");
    if (!card || !visual || reduce) return;
    let frame = 0;
    visual.addEventListener("pointermove", e => {
      if (!fine.matches) return;
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => {
        const r = visual.getBoundingClientRect();
        const x = (e.clientX - r.left) / r.width - 0.5;
        const y = (e.clientY - r.top) / r.height - 0.5;
        card.style.setProperty("--ry", `${(x * 10).toFixed(2)}deg`);
        card.style.setProperty("--rx", `${(-y * 8).toFixed(2)}deg`);
      });
    });
    visual.addEventListener("pointerleave", () => {
      card.style.setProperty("--ry", "0deg");
      card.style.setProperty("--rx", "0deg");
    });
  });
})();
