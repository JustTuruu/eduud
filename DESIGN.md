---
name: E-Duud
description: Монгол penny-auction апп — live дуудлага худалдааг "одоо тоглож буй" дуу шиг харуулна.
colors:
  plum-night: "#140B1C"
  plum-surface: "#1A1024"
  plum-raised: "#2A1B3D"
  cream-ink: "#F3E9DC"
  cream-soft: "#D8CCD6"
  mauve-muted: "#A999B4"
  cream-hairline: "#14F3E9DC"
  cream-hairline-strong: "#29F3E9DC"
  ember-coral: "#FF6B4A"
  coral-glow: "#FF9275"
  cta-ink: "#1C0C16"
  live-rose: "#FF4F7B"
  win-gold: "#F2C14E"
  success-mint: "#63D9A4"
  danger-rose: "#FF7A85"
  warn-amber: "#FFB547"
typography:
  display:
    fontFamily: "Manrope, sans-serif"
    fontSize: "40px"
    fontWeight: 800
    letterSpacing: "-0.3px"
    fontFeature: "tnum"
  price-hero:
    fontFamily: "Manrope, sans-serif"
    fontSize: "44px"
    fontWeight: 800
    lineHeight: 1.1
    letterSpacing: "-0.5px"
    fontFeature: "tnum"
  headline:
    fontFamily: "Manrope, sans-serif"
    fontSize: "23px"
    fontWeight: 800
    letterSpacing: "-0.3px"
  title:
    fontFamily: "Manrope, sans-serif"
    fontSize: "22px"
    fontWeight: 800
  body:
    fontFamily: "Manrope, sans-serif"
    fontSize: "14px"
    fontWeight: 500
    lineHeight: 1.5
  label:
    fontFamily: "Manrope, sans-serif"
    fontSize: "13px"
    fontWeight: 700
  nav-label:
    fontFamily: "Manrope, sans-serif"
    fontSize: "11.5px"
    fontWeight: 600
rounded:
  chip: "14px"
  control: "18px"
  tile: "20px"
  card: "24px"
  art: "28px"
  nav: "30px"
  sheet: "32px"
  pill: "999px"
spacing:
  xxs: "4px"
  xs: "8px"
  sm: "12px"
  md: "16px"
  gutter: "20px"
  lg: "24px"
  section: "40px"
components:
  button-bid:
    backgroundColor: "{colors.ember-coral}"
    textColor: "{colors.cta-ink}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    height: "56px"
    width: "100%"
  button-primary:
    backgroundColor: "{colors.ember-coral}"
    textColor: "{colors.cta-ink}"
    rounded: "{rounded.control}"
    padding: "16px 24px"
  button-primary-busy:
    backgroundColor: "{colors.plum-raised}"
    textColor: "{colors.mauve-muted}"
  input:
    backgroundColor: "{colors.plum-surface}"
    textColor: "{colors.cream-ink}"
    rounded: "{rounded.control}"
    padding: "16px"
  chip-token:
    backgroundColor: "{colors.plum-raised}"
    textColor: "{colors.cream-ink}"
    rounded: "{rounded.pill}"
    padding: "8px 14px"
  chip-status:
    backgroundColor: "{colors.plum-surface}"
    rounded: "{rounded.pill}"
    padding: "5px 10px"
  card-request:
    backgroundColor: "{colors.plum-surface}"
    textColor: "{colors.cream-ink}"
    rounded: "{rounded.tile}"
    padding: "16px"
  nav-floating:
    backgroundColor: "{colors.plum-surface}"
    rounded: "{rounded.nav}"
    height: "64px"
  nav-item-active:
    backgroundColor: "{colors.ember-coral}"
    textColor: "{colors.cream-ink}"
    rounded: "{rounded.card}"
  auction-tile:
    rounded: "{rounded.tile}"
    width: "148px"
  now-artwork:
    rounded: "{rounded.art}"
---

# Design System: E-Duud

## Overview

**Creative North Star: "Now Playing"**

A live auction is the track that is playing right now. The item photo is the album cover, the countdown is the scrub bar, and the bid is the play button. One live item owns the screen: a large square artwork, its name and leader, a big tabular price, a progress timer, and one coral bid control. Everything else (upcoming, ended) sits below as horizontal album shelves that snap a whole card at a time.

The world is a deep plum night tinted by the artwork itself. The ambient backdrop pulls three colours from the active item's image and spreads them as slow-drifting, heavily dimmed blobs over the plum base, cross-fading in 900ms when the item changes. Text is warm cream, never grey. Coral is the single action voice. Depth comes from soft drop shadows under artwork and from one glass surface, the floating nav.

Density is low on the hero and medium on shelves and forms. The auction data (price, leader, bid count, remaining time) is the content; the music-player grammar is the frame, not a copy of any player's icons or layout.

**Key Characteristics:**
- Image-derived ambient colour field over a plum base, with a bottom-darkening scrim for contrast.
- One coral action per screen; coral also marks progress and the active tab.
- Manrope throughout; money and counts are weight 800 with tabular figures.
- Large rounded square artwork (20-28px corners) with deep soft shadows.
- 1px cream hairlines at 8% for borders and dividers.
- Floating glass capsule nav (blur 30) as the only frosted chrome.

## Colors

A warm-dark palette: plum grounds, cream ink, one coral accent, and a small set of semantic hues that each mean one thing.

### Primary
- **Ember Coral** (ember-coral): the bid button, primary CTA gradient, timer progress fill, active nav pill (at 16% fill, 28% border), wordmark "DUUD", focused input border, "Бүгд" shelf links.
- **Coral Glow** (coral-glow): the lighter coral the timer pulses toward in the last seconds, and coral icons on tiles (clock).
- **CTA Ink** (cta-ink): dark plum text and icons on coral, around 6:1 contrast. Never cream on coral.

### Neutral
- **Plum Night** (plum-night): scaffold and ambient base colour.
- **Plum Surface** (plum-surface): inputs (at 70%), request cards (at 78%), glass nav fill (at 62%).
- **Plum Raised** (plum-raised): token chip, snackbars, busy button, empty-state discs.
- **Cream Ink** (cream-ink): headings, prices, primary text.
- **Cream Soft** (cream-soft): secondary text, leader line, timer and bid count.
- **Mauve Muted** (mauve-muted): hints, tertiary meta, inactive nav.
- **Cream Hairline** (cream-hairline, cream 8%) and **Strong Hairline** (cream-hairline-strong, cream 16%): every border and divider; the strong one rims glass and snackbars.

### Semantic
- **Live Rose** (live-rose): live-state badge dot only.
- **Win Gold** (win-gold): final winning price on ended tiles. Only wins.
- **Success Mint**, **Danger Rose**, **Warn Amber**: form and request-status states, used at about 12-14% as backgrounds with the full hue as text.

### Named Rules
**The One Voice Rule.** Coral is the only action colour. If something is coral, it is the bid, the primary CTA, progress, or the current location.

**The Cream Not Grey Rule.** Text hues stay in the cream-to-mauve family; no neutral greys.

**The Gold Means Won Rule.** Gold appears only where someone has won.

## Typography

**Display Font:** Manrope (Google Fonts, Cyrillic)
**Body Font:** Manrope

**Character:** One geometric-humanist family carries everything; hierarchy comes from weight (500-800) and size, not from a second face. Tabular figures keep prices and timers from jittering while they update live.

### Hierarchy
- **Display** (800, 40px, -0.3px tracking, tabular): large numeric moments.
- **Price Hero** (800, 44px, 1.1, -0.5px, tabular): the live price; it rolls upward on each new bid. Smaller prices use the same style at 15-28px.
- **Headline** (800, 23px): screen titles ("Одоо явагдаж буй") and shelf headers ("Удахгүй эхлэх", "Дууссан").
- **Title** (800, 22px): the live item's name; 16px/800 for request card titles.
- **Body** (500, 14px, 1.5): leader line, meta, helper text; tile meta is 12.5px.
- **Label** (700, 13px): field labels and small section labels. Sentence case, no tracking.
- **Nav Label** (600 inactive / 800 active, 11.5px).

### Named Rules
**The Tabular Money Rule.** Every price, countdown and count uses tabular figures at weight 700-800.

**The Plain Label Rule.** Section and field labels are sentence-case 13px/700 with no letter-spacing. No eyebrows.

## Layout

Mobile first with 20px horizontal gutters. The hero artwork is a square about 78% of the viewport width (capped at 360px). A PageView swipes between multiple live items with dot indicators below (active dot is a coral bar). The info block stacks name, then 4px, leader, 12px, price, 16px, timer bar, 24px, bid button. Shelves are horizontal lists of 148px tiles (184px wide) with 14px gaps and snap-by-card physics, separated by 40px.

At 900px and above (`Breakpoints.wide`), the floating bottom nav becomes a glass top capsule (max 1200px) with wordmark, the same three destinations and the token chip. The hero becomes two columns: artwork on the left with arrow buttons and dots, info and bid on the right. Forms sit in a 720px PageFrame. Grids switch to two columns at 700px and three at 1080px.

Content keeps bottom padding equal to the nav height plus gaps (`NavMetrics.bottomInset`) so the floating nav never covers it. Snackbars float 104px above the bottom for the same reason.

## Elevation & Depth

Depth has three sources: the ambient colour field behind everything, soft long drop shadows under artwork and cards, and one frosted glass layer for navigation. Shadows are always blurred and offset downward. They are never hard-edged or offset sideways.

### Shadow Vocabulary
- **Artwork drop** (black 50%, blur 40, y 22): under the live hero artwork.
- **Card drop** (black 40%, blur 24): GlowCard surfaces.
- **Glass float** (black 45%, blur 32, y 14): under the nav capsule.
- **Coral halo** (coral 38%, blur 26, y 10): under the bid button only; on primary CTA 30% at rest, 55% when pressed.
- **Urgency glow** (coral, blur 6-14, pulsing): on the timer fill in the final seconds.

### Named Rules
**The Glass Is For Floating Rule.** Backdrop blur (sigma 30) belongs to floating chrome (the nav capsule) and to chips laid over artwork. Content surfaces are tinted plum, not frosted.

**The Coral Halo Rule.** A coloured glow is reserved for the coral action and urgent progress. Ordinary surfaces get neutral black shadows.

## Shapes

Generous, soft rounding that scales with importance. Chips and snackbars use 14px, controls and inputs 18px, shelf tiles and request cards 20px, cards 24px, the hero artwork 28px, the nav capsule 30px, sheets 32px at the top. Status pills, the token chip, the bid button (56px high, 28px radius) and the top-nav items are full pills. All artwork is square (1:1). Borders are 1px hairlines. Focused inputs thicken to a 1.6px coral border.

## Components

### Buttons
- **Bid button:** the single isolated primary action. Full width, 56px pill, coral vertical gradient (#FF7556 to #FF6140), gavel icon (20px) and "Санал өгөх" in 16px/800 cta-ink, coral halo. Press scales to 0.96 with medium haptic. Busy state turns plum-raised with a coral spinner and no halo. Nothing tappable sits close to it.
- **Primary button:** same gradient and ink, 18px radius, 15.5px/800 label, optional icon that swings like a hammer strike on press.
- **Secondary:** transparent with a hairline border, 18px radius, cream label ("Ноорог хадгалах").
- **Press feedback:** every tappable element shrinks slightly (AnimatedPressable, 0.96-0.97) with a light haptic.

### Chips
- **Token chip:** plum-raised at 70%, pill, coral diamond icon, 14px/800 tabular count. It sits top-right on Home and at the right of the wide top nav.
- **Status pill:** status hue at 14% fill, 12px/800 text in the full hue, pill shape.
- **Choice chips** (request category): plum surface tiles at control radius.
- **Glass chip:** white 7% fill, white 12% border, blurred, used over artwork.

### Cards / Containers
- **Corner Style:** 20px for request cards and tiles, 24px for GlowCard.
- **Background:** plum-surface at 78%, or the plum card gradient (#231533 to #1C1129).
- **Shadow Strategy:** card drop (see Elevation).
- **Border:** 1px cream hairline.
- **Internal Padding:** 16px.

### Inputs / Fields
- **Style:** plum-surface at 70% fill, 1px hairline border, 18px radius, 16px padding, mauve hints. The label sits above in 13px/700.
- **Focus:** the border becomes 1.6px coral, with a coral cursor and selection.
- **Error:** 1.4px danger border (1.8px when focused). The message is drawn by the field with an icon and text, never by colour alone.

### Navigation
- **Bottom (narrow):** a floating glass capsule, max 420px, 64px high, 30px radius, 16px above the safe area, three labelled tabs (Нүүр, Хүсэлт, Профайл). A coral pill (16% fill, 28% border, 24px radius) slides to the active tab on a spring (stiffness 320, damping 26). The active icon bounces once (scale 1 to 1.22 to 1) and turns coral, and its label goes to 800 weight.
- **Top (≥900px):** the same glass capsule holding the wordmark, pill tabs (icon 17px plus 13.5px label) and the token chip on the right.
- **Tab change:** content slides 22px in the direction of travel and fades from 25% (320ms, easeOutQuint). Branch state is preserved.

### Now Playing hero (signature)
Square artwork (28px radius, artwork drop) that does a "beat" on each new bid (1.0 to 1.03 to 1.0, 420ms). Below it: name, "Тэргүүлж буй:" leader, rolling hero price, then the timer bar. The timer bar is a 5px track in cream 14% with a coral fill whose length equals the exact remaining fraction of the time window, plus a 14px cream thumb. In the final 10 seconds the fill and thumb pulse between coral and coral-glow with a glow, and the remaining time turns coral. Below the bar, remaining time sits on the left and bid count on the right, both 14px tabular.

### Album shelf tile
A square 20px-radius artwork, then 8px, a 14px title (one line, ellipsis), then meta: a coral clock plus start time for upcoming, or winner name plus a gold 15px price for ended. When there is no image, the placeholder is a gradient derived from the auction id's seed colours.

### Ambient backdrop (signature)
A plum-night base painted with three radial blobs (alpha 0.62 / 0.42 / 0.40, mixed 80% toward the image colour). The blobs drift on a 40s loop and are covered by a top-to-bottom plum scrim (10% to 72%). Colours come from the active image via ColorScheme.fromImageProvider, or from a deterministic seed when there is no image. Under reduced motion the drift stops and colour changes happen instantly.

## Do's and Don'ts

### Do:
- **Do** let the active item's artwork tint the whole screen through AmbientBackdrop, and cross-fade it over 900ms when the item changes.
- **Do** keep exactly one coral action per screen and give it room.
- **Do** set every price, countdown and count in Manrope 800 with tabular figures.
- **Do** make the timer bar's length equal the true remaining fraction of the time window.
- **Do** use 1px cream hairlines (8%, 16% on glass) for borders and dividers.
- **Do** honour reduced motion: springs, beats, drift and slides collapse to instant changes.
- **Do** pad content by the nav inset so the floating nav never covers it.

### Don't:
- **Don't** use neutral greys for text; stay in cream, cream-soft and mauve.
- **Don't** put cream text on coral; use cta-ink.
- **Don't** use gold for anything except a win.
- **Don't** frost content cards; blur is for floating chrome and chips over artwork.
- **Don't** add eyebrow or kicker labels (small tracked uppercase lines above headings).
- **Don't** use hard-edged or sideways-offset shadows.
- **Don't** copy a music player's icons or layout; the auction data is the content.
