# Frontend Taste

Senior UI/UX engineering rules that override default model biases toward generic output. Apply these when generating or modifying frontend UI: pages, layouts, components, forms, dashboards, landing pages, animations, responsive UI, and loading, empty, and error states. Do not apply them to backend-only work, database code, scripts, API-only tasks, or config-only changes.

## Baseline Frontend Rules

If the detailed rules below cannot be applied in full, at minimum:

- use Tailwind CSS
- avoid generic AI-looking UI
- avoid emojis unless requested
- avoid centered hero layouts unless explicitly requested
- use responsive layouts
- include loading, empty, and error states when relevant
- check `package.json` before importing UI, icon, or animation libraries
- follow existing design-system and styling conventions before adding new ones

## Active Baseline Configuration

- DESIGN_VARIANCE: 8 (1=Perfect Symmetry, 10=Artsy Chaos)
- MOTION_INTENSITY: 6 (1=Static/No movement, 10=Cinematic/Magic Physics)
- VISUAL_DENSITY: 4 (1=Art Gallery/Airy, 10=Pilot Cockpit/Packed Data)

The standard baseline for all generations is strictly set to these values (8, 6, 4). Always listen to the user: adapt these values dynamically based on what they explicitly request. Use these baseline (or user-overridden) values as global variables to drive the specific logic in the sections below.

## Default Architecture And Conventions

Unless the user explicitly specifies a different stack, adhere to these structural constraints:

- **Dependency verification [mandatory]:** Before importing any third-party library (for example `framer-motion`, `lucide-react`, `zustand`), you must check `package.json`. If the package is missing, output the installation command (for example `npm install package-name`) before providing the code. Never assume a library exists.
- **Framework and interactivity:** React or Next.js. Default to Server Components (RSC).
  - **RSC safety:** Global state works only in Client Components. In Next.js, wrap providers in a `"use client"` component.
  - **Interactivity isolation:** If motion or liquid-glass sections are active, the specific interactive UI component must be extracted as an isolated leaf component with `'use client'` at the very top. Server Components must exclusively render static layouts.
- **State management:** Use local `useState`/`useReducer` for isolated UI. Use global state strictly to avoid deep prop-drilling.
- **Styling policy:** Use Tailwind CSS (v3/v4) for 90% of styling.
  - **Tailwind version lock:** Check `package.json` first. Do not use v4 syntax in v3 projects.
  - **T4 config guard:** For v4, do not use the `tailwindcss` plugin in `postcss.config.js`. Use `@tailwindcss/postcss` or the Vite plugin.
- **Anti-emoji policy [critical]:** Never use emojis in code, markup, text content, or alt text. Replace symbols with high-quality icons (Radix, Phosphor) or clean SVG primitives.
- **Responsiveness and spacing:**
  - Standardize breakpoints (`sm`, `md`, `lg`, `xl`).
  - Contain page layouts using `max-w-[1400px] mx-auto` or `max-w-7xl`.
  - **Viewport stability [critical]:** Never use `h-screen` for full-height hero sections. Always use `min-h-[100dvh]` to prevent layout jumping on mobile browsers.
  - **Grid over flex-math:** Never use complex flexbox percentage math (`w-[calc(33%-1rem)]`). Always use CSS Grid (`grid grid-cols-1 md:grid-cols-3 gap-6`) for reliable structures.
- **Icons:** Use exactly `@phosphor-icons/react` or `@radix-ui/react-icons` as the import paths (check installed version). Standardize `strokeWidth` globally (for example exclusively `1.5` or `2.0`).

## Design Engineering Directives (Bias Correction)

**Rule 1: Deterministic typography.**

- Display/headlines: default to `text-4xl md:text-6xl tracking-tighter leading-none`. Discourage `Inter` for premium or creative vibes; force unique character using `Geist`, `Outfit`, `Cabinet Grotesk`, or `Satoshi`. Serif fonts are banned for dashboard/software UIs; use high-end sans-serif pairings (`Geist` + `Geist Mono` or `Satoshi` + `JetBrains Mono`).
- Body/paragraphs: default to `text-base text-gray-600 leading-relaxed max-w-[65ch]`.

**Rule 2: Color calibration.**

- Max 1 accent color. Saturation < 80%.
- The "AI purple/blue" aesthetic is banned: no purple button glows, no neon gradients. Use absolute neutral bases (Zinc/Slate) with high-contrast, singular accents (for example Emerald, Electric Blue, or Deep Rose).
- Stick to one palette for the entire output. Do not fluctuate between warm and cool grays within the same project.

**Rule 3: Layout diversification.**

- Centered Hero/H1 sections are banned when variance > 4. Force split-screen (50/50), left-aligned content with right-aligned asset, or asymmetric white-space structures.

**Rule 4: Materiality, shadows, and anti-card overuse.**

- For density > 7, generic card containers are banned. Use logic-grouping via `border-t`, `divide-y`, or purely negative space. Data metrics should breathe without being boxed in unless elevation is functionally required.
- Use cards only when elevation communicates hierarchy. When a shadow is used, tint it to the background hue.

**Rule 5: Interactive UI states.**

- Implement full interaction cycles, not just static success states:
  - Loading: skeletal loaders matching layout sizes (avoid generic circular spinners).
  - Empty states: beautifully composed empty states indicating how to populate data.
  - Error states: clear, inline error reporting (for example on forms).
  - Tactile feedback: on `:active`, use `-translate-y-[1px]` or `scale-[0.98]` to simulate a physical push.

**Rule 6: Data and form patterns.**

- Forms: label must sit above input. Helper text optional but present in markup. Error text below input. Use a standard `gap-2` for input blocks.

## Creative Proactivity (Anti-Slop Implementation)

- **Liquid glass refraction:** When glassmorphism is needed, go beyond `backdrop-blur`. Add a 1px inner border (`border-white/10`) and a subtle inner shadow (`shadow-[inset_0_1px_0_rgba(255,255,255,0.1)]`) to simulate physical edge refraction.
- **Magnetic micro-physics (if motion > 5):** Buttons that pull slightly toward the cursor. Never use React `useState` for magnetic hover or continuous animations. Use Framer Motion's `useMotionValue` and `useTransform` outside the render cycle.
- **Perpetual micro-interactions:** When motion > 5, embed continuous, infinite micro-animations (Pulse, Typewriter, Float, Shimmer, Carousel) in standard components. Apply spring physics (`type: "spring", stiffness: 100, damping: 20`) to interactive elements; no linear easing.
- **Layout transitions:** Use Framer Motion's `layout` and `layoutId` props for smooth re-ordering, resizing, and shared element transitions.
- **Staggered orchestration:** Do not mount lists or grids instantly. Use `staggerChildren` or CSS cascade (`animation-delay: calc(var(--index) * 100ms)`). For `staggerChildren`, the parent (`variants`) and children must reside in the identical Client Component tree.

## Performance Guardrails

- Apply grain/noise filters exclusively to fixed, pointer-event-none pseudo-elements and never to scrolling containers.
- Never animate `top`, `left`, `width`, or `height`. Animate exclusively via `transform` and `opacity`.
- Never spam arbitrary `z-50` or `z-10`. Use z-indexes strictly for systemic layer contexts (sticky navbars, modals, overlays).

## Technical Reference (Dial Definitions)

**DESIGN_VARIANCE.** 1-3 predictable (flex `justify-center`, symmetrical grids); 4-7 offset (negative-margin overlaps, varied aspect ratios, left-aligned headers); 8-10 asymmetric (masonry, fractional grid units, large empty zones). Mobile override: for levels 4-10, asymmetric layouts above `md:` must fall back to a strict single-column layout on viewports `< 768px`.

**MOTION_INTENSITY.** 1-3 static (hover/active only); 4-7 fluid CSS (`transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1)`, transform/opacity focus); 8-10 advanced choreography (scroll-triggered reveals or parallax via Framer Motion hooks; never `window.addEventListener('scroll')`).

**VISUAL_DENSITY.** 1-3 art gallery (lots of white space); 4-7 daily app (normal spacing); 8-10 cockpit (tiny paddings, 1px separators, mandatory `font-mono` for numbers).

## AI Tells (Forbidden Patterns)

Avoid these signatures unless explicitly requested.

Visual and CSS: no neon/outer glows; no pure black (`#000000`) — use off-black/Zinc-950/Charcoal; no oversaturated accents; no excessive gradient text; no custom mouse cursors.

Typography: no `Inter` (use `Geist`, `Outfit`, `Cabinet Grotesk`, or `Satoshi`); no oversized H1s — control hierarchy with weight and color; serif only for creative/editorial, never on clean dashboards.

Layout and spacing: align and space mathematically; no generic "3 equal cards horizontally" feature rows — use a 2-column zig-zag, asymmetric grid, or horizontal scroll.

Content and data: no generic names ("John Doe", "Sarah Chan"); no generic "egg"/default user-icon avatars; no fake numbers (`99.99%`, `50%`) — use organic messy data (`47.2%`, `+1 (312) 847-1928`); no startup-slop names ("Acme", "Nexus", "SmartFlow"); no filler words ("Elevate", "Seamless", "Unleash", "Next-Gen") — use concrete verbs.

External resources and components: no Unsplash — use reliable placeholders like `https://picsum.photos/seed/{random_string}/800/600` or SVG UI avatars; you may use `shadcn/ui` but never in its default state — customize radii, colors, and shadows; keep code clean, striking, and refined.

## The Creative Arsenal (High-End Inspiration)

Pull from advanced concepts rather than defaulting to generic UI. When appropriate, leverage GSAP (ScrollTrigger/Parallax) for complex scrolltelling or Three.js/WebGL for 3D/canvas, rather than basic CSS motion. Never mix GSAP/Three.js with Framer Motion in the same component tree. Default to Framer Motion for UI/bento interactions; use GSAP/Three.js exclusively for isolated full-page scrolltelling or canvas backgrounds, wrapped in strict `useEffect` cleanup.

Representative patterns: asymmetric hero paradigms; navigation (macOS dock magnification, magnetic button, gooey menu, dynamic island, contextual radial menu, floating speed dial, mega menu reveal); layout and grids (bento grid, masonry, chroma grid, split-screen scroll, curtain reveal); cards and containers (parallax tilt, spotlight border, glassmorphism panel, holographic foil, tinder swipe stack, morphing modal); scroll animations (sticky scroll stack, horizontal scroll hijack, locomotive sequence, zoom parallax, scroll progress path, liquid swipe); galleries and media (dome gallery, coverflow carousel, drag-to-pan grid, accordion image slider, hover image trail, glitch effect); typography and text (kinetic marquee, text mask reveal, text scramble, circular text path, gradient stroke animation, kinetic typography grid); micro-interactions (particle explosion button, liquid pull-to-refresh, skeleton shimmer, directional hover-aware button, ripple click, animated SVG line drawing, mesh gradient background, lens blur depth).

## The Motion-Engine Bento Paradigm

For modern SaaS dashboards or feature sections, use a "Bento 2.0" architecture and motion philosophy (Vercel-core meets Dribbble-clean).

Core design philosophy: high-end, minimal, functional. Background `#f9fafb`; cards pure white (`#ffffff`) with a 1px `border-slate-200/50`. Use `rounded-[2.5rem]` for major containers and a light, wide diffusion shadow (for example `shadow-[0_20px_40px_-15px_rgba(0,0,0,0.05)]`). Strict `Geist`, `Satoshi`, or `Cabinet Grotesk` fonts with `tracking-tight` headers. Titles and descriptions placed outside and below the cards. Generous `p-8` or `p-10` padding inside cards.

Animation engine: no linear easing — use `type: "spring", stiffness: 100, damping: 20`; heavily use `layout` and `layoutId`; every card has an infinite active-state loop (Pulse, Typewriter, Float, or Carousel); wrap dynamic lists in `<AnimatePresence>` and optimize for 60fps; memoize (`React.memo`) and isolate any perpetual motion in its own microscopic Client Component.

Card archetypes: the intelligent list (infinite auto-sorting via `layoutId`); the command input (multi-step typewriter with blinking cursor and shimmering processing state); the live status (breathing indicators with overshoot-spring notification badge); the wide data stream (seamless infinite carousel via `x: ["0%", "-100%"]`); the contextual UI (staggered highlight with float-in toolbar).

## Final Pre-Flight Check

Evaluate code against this matrix before outputting:

- [ ] Is global state used appropriately to avoid deep prop-drilling rather than arbitrarily?
- [ ] Is mobile layout collapse (`w-full`, `px-4`, `max-w-7xl mx-auto`) guaranteed for high-variance designs?
- [ ] Do full-height sections safely use `min-h-[100dvh]` instead of the bugged `h-screen`?
- [ ] Do `useEffect` animations contain strict cleanup functions?
- [ ] Are empty, loading, and error states provided?
- [ ] Are cards omitted in favor of spacing where possible?
- [ ] Did you strictly isolate CPU-heavy perpetual animations in their own Client Components?
