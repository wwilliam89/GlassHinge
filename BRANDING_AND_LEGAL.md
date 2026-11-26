# GlassHinge — prior attempts, legal review, pricing, branding

*Prepared 2026-10-19. This is a practical risk review, not legal advice.
If the app starts earning real money, spend an hour with a trademark/IP
attorney before filing anything or scaling ads.*

## 1. Is there an attempt already? — Yes, several. None blocks us.

The lid-angle trick is a small, busy hobbyist scene:

| Attempt | What it is | Where | Notes for us |
|---|---|---|---|
| LidAngleSensor (Sam Henri Gold) | The original proof-of-concept: reads the sensor, plays door-creak / theremin sounds | GitHub / Homebrew, free | Established the public HID specs everyone uses (VID 0x05AC / PID 0x8104, Sensor page, Orientation usage). Facts/specs aren't copyrightable. |
| Liddy (MisterJerkins) | Lid animation using ScreenCaptureKit + Metal perspective re-projection | GitHub, **MIT license**, signed but not notarized, not on the App Store | MIT would even permit reuse *with attribution* — but we didn't reuse it. Our implementation is different tech (system visual-effect blur, no screen capture, no Metal). |
| Softfold (ReffWu) | "Close the lid, and your desktop folds away softly" — perspective fold + progressive blur | GitHub, free | Closest in spirit to ours; not an App Store product. |
| Lid Plane (jh3y) | Lid-angle-driven progressive blur menu-bar app | GitHub DMG, free, experimental | Needs Screen Recording permission; ours doesn't. |
| UnfoldMyMac | Commercial pack: 13 lid effects + 20 dynamic wallpapers | Sold from its own website | Proves people pay for lid effects; not on the Mac App Store. |
| Sway (Wyverse Labs) | Perspective + blur + shadow as you move the lid | Website says "Coming soon", **US$2.99 one-time** | Our nearest commercial comp and our price anchor. Requires Screen Recording + macOS 14+; we're macOS 13+, no screen recording, Intel + non-sensor support. |

**What this means:** the *idea* is out there and nobody owns it — ideas and
functional techniques aren't protected by copyright. What *is* protected:
their names, code, art, and copy. We use none of those (all code, copy, and
icon art here is original). Our differentiation for the store: first
App-Store-native, sandboxed, no-permission version that also works on
Macs *without* the sensor. I found no listing under any of these names in
Mac App Store search results; do one final in-store search for "hinge" /
"lid" before submitting, since store search isn't fully visible from the web.

## 2. Legal review — naming, copyright, Apple rules

### Trademark / naming
- **Chosen name: GlassHinge.** Web + trademark-database searches surfaced
  **no existing software product or registration called "GlassHinge."**
  "Hinge Health" exists but is health/exercise software — a different field,
  low confusion risk. *Caveat:* a web search is not a full USPTO TESS
  clearance. Before spending on ads, run a proper TESS search (Class 9,
  downloadable software) or have an attorney do it; filing your own
  intent-to-use application later is a few hundred dollars if it earns.
- **Never put these in the app name, subtitle, or keywords:** iPhone, Duo,
  MacBook, Apple, Liquid Glass. Apple's Guideline 5.2.1 bans third-party
  protected material — including trademarks — in your app *and metadata*
  without authorization. The original draft said "Duo-style"; I've removed
  every such reference from the code, in-app strings, and the listing in
  this package. (Describing inspiration in a repo README or a press pitch is
  nominative and lower-risk; store metadata is where Apple is strict.)
- **Implied endorsement:** Guideline 5.2.4 — don't suggest Apple is the
  source of or endorses the app. The listing includes an explicit
  "independent app, not affiliated with Apple" line in the review notes,
  and no Apple logos, product renders, emoji, or marketing imagery are used
  anywhere, including the icon.

### Copyright
- Effect = idea/technique (not protected). Code, description text, and icon
  art in this package = original (protected *for you* automatically on
  creation — put your legal name in the App Store Connect copyright field,
  format "2026 Your Name").
- Do **not** use: Apple's fold animation footage, Apple wallpapers or
  screenshots, or copy from Apple's product pages anywhere in the listing
  or screenshots. Our screenshots are of our own effect over a generic desktop.
- Sensor identifiers (VID/PID, HID usages) are functional facts, not
  creative expression — using them is standard interoperability.

### Apple product-similarity (Guideline 5.2.5)
"Don't create an app that appears confusingly similar to an existing Apple
product or interface." A decorative blur overlay doesn't imitate any Apple
app's interface, name, or iconography, so risk here is **low** — the residual
risk is a subjective reviewer call on any "inspired-by" framing, which is
why the listing now sells the effect generically ("fold-style glass")
instead of naming the inspiration. If a reviewer pushes back, the usual fix
is softening description wording, not removing the app.

### Patents (honest residual risk)
Foldable-display behaviour is a heavily patented area for *hardware and
on-device foldable software*. A blur overlay on a laptop doesn't implement
foldable-display technology, and I found nothing targeting this. Risk
assessed **low, not zero** — no one can promise zero without a formal
freedom-to-operate opinion, which isn't worth buying at this scale.

### Bottom line
With the cleaned metadata in this package: **no known legal blocker to
listing.** Biggest realistic risk isn't a lawsuit — it's an App Review
metadata rejection (fixable in a day) — so keep the listing exactly as
clean as APP_STORE.md.

## 3. Pricing — my recommendation

**Launch free → Pro one-time $3.99. Do not flip the whole app paid.**

- **Phase 1 (v1.0, free, ~4–8 weeks):** everything in the current build.
  Goal is installs, ratings (target 1,000+ installs, 20+ ratings), and
  keyword ranking while there's zero price friction.
- **Phase 2 (v1.1):** keep everything free that was free (Apple expects this
  and users review-bomb apps that paywall old features) and add **Pro as a
  one-time $3.99 In-App Purchase**: extra styles (e.g. Prism, Curtains,
  Crease Glow), per-display styles, finer angle tuning. One-time, **not a
  subscription** — people won't subscribe to a novelty utility.
  Full Pro list: **Style Pack** (Prism refraction edge, Smoked/Midnight
  dark glass, Sunset warm tint, Crease Glow hinge light, Curtains sweep) ·
  **Custom tint picker** (any colour, per style) · **Motion Lab**
  (movement sensitivity, settle/clear speed, shine strength) · **Per-display
  styles** incl. external monitors · **Wake greeting** (optional clock /
  short message inside the wake dissolve) · **Subtle sound pack**
  (optional glass shimmer, off by default). All original names/designs,
  all on-device — the 3 launch styles (Ocean Blue, Clear Glass, Frost, all
  original descriptive names built on standard system materials) and the
  core effect stay free forever.
- **Why $3.99:** the nearest commercial comp (Sway) advertises **$2.99
  one-time**. We support more Macs (macOS 13+, Intel, non-sensor models)
  and need no Screen Recording permission, so +$1 is defensible; at the
  Small Business Program's 15% you net ≈ **$3.39/sale** (vs $2.79 at the
  standard 30%). If conversion is weak after a month, drop Pro to $2.99 as
  a "sale" — price drops are easy, price rises on an unlock are not.
- **Why not flip the whole app to $1.99–$2.99 later:** existing free users
  keep it free anyway, you'd only charge new users, and a paid-up-front
  novelty app gets a fraction of the installs — killing the ranking momentum
  the free phase built. Freemium keeps both.

## 4. Final branding

- **Name:** GlassHinge — tagline: *"Move your lid, watch the glass."*
- **Icon:** Concept **D "Laptop"** — front-view laptop in landscape with the
  glass glow as a *horizontal* line along the hinge at the bottom of the
  lid — is installed in the project (the user correctly pointed out that
  the first pick's vertical crease was phone language; a laptop hinge is
  horizontal). Alternates in `branding/`: E "Profile" (side-view hinge),
  B "Crease Glow", A "Two Panes", C "Frost Sweep".
- **Voice:** playful, one line at a time. Never reference other products by
  name in store copy.
- **Descriptions:** full listing copy (name, subtitle, promo text,
  keywords, description, What's New, review notes) is in `APP_STORE.md`.
