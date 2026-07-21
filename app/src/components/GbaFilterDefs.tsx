/** Hidden SVG filter definitions shared by all card art (real photos and pixel sprites alike) to
 * give everything a consistent "old handheld console" look: a quantized/posterized color palette
 * (few discrete levels per channel, like a 15-bit GBA screen) plus a touch of softness. Mount
 * this once near the app root; components reference it via `filter: url(#gba-retro)`. */
export function GbaFilterDefs() {
  return (
    <svg aria-hidden="true" style={{ position: 'absolute', width: 0, height: 0, overflow: 'hidden' }}>
      <defs>
        <filter id="gba-retro" colorInterpolationFilters="sRGB">
          <feComponentTransfer>
            <feFuncR type="discrete" tableValues="0 0.13 0.27 0.4 0.53 0.67 0.8 0.93 1" />
            <feFuncG type="discrete" tableValues="0 0.13 0.27 0.4 0.53 0.67 0.8 0.93 1" />
            <feFuncB type="discrete" tableValues="0 0.13 0.27 0.4 0.53 0.67 0.8 0.93 1" />
          </feComponentTransfer>
        </filter>
      </defs>
    </svg>
  )
}
