export type Argb = number;

export function argbFromRgb(red: number, green: number, blue: number): Argb {
  return ((0xff << 24) | ((red & 0xff) << 16) | ((green & 0xff) << 8) | (blue & 0xff)) >>> 0;
}

export function redFromArgb(argb: Argb): number {
  return (argb >> 16) & 0xff;
}

export function greenFromArgb(argb: Argb): number {
  return (argb >> 8) & 0xff;
}

export function blueFromArgb(argb: Argb): number {
  return argb & 0xff;
}

export function alphaFromArgb(argb: Argb): number {
  return (argb >>> 24) & 0xff;
}

export function hexFromArgb(argb: Argb, leadingHashSign = true): string {
  const hex = (argb & 0x00ffffff).toString(16).padStart(6, '0').toUpperCase();
  return leadingHashSign ? `#${hex}` : hex;
}

export function argbFromHex(hex: string): Argb {
  const normalized = hex.trim().replace(/^#/, '');
  if (!/^[0-9a-fA-F]{6}$/.test(normalized) && !/^[0-9a-fA-F]{8}$/.test(normalized)) {
    throw new Error(`Invalid hex color: ${hex}`);
  }
  const value = Number.parseInt(normalized, 16);
  return normalized.length === 6 ? (0xff000000 | value) >>> 0 : value >>> 0;
}

export function asOpaqueArgb(argb: Argb): Argb {
  return (0xff000000 | (argb & 0x00ffffff)) >>> 0;
}
