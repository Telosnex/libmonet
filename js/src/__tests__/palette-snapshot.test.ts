import {describe, expect, test} from 'vitest';
import {Algo, Palette, PaletteSnapshot, paletteRoles} from '../index.js';

describe('PaletteSnapshot', () => {
  test('captures all palette roles and exposes stable getters', () => {
    const palette = Palette.from(0xff1177aa, {backgroundTone: 93, algo: Algo.apca});
    const snapshot = PaletteSnapshot.capture(palette);
    expect(snapshot.toRecord()).toEqual(palette.toRecord());
    expect(snapshot.background).toBe(palette.background);
    expect(snapshot.color).toBe(palette.color);
    expect(snapshot.fillSplashedBorder).toBe(palette.fillSplashedBorder);
    expect(Object.keys(snapshot.toRecord()).sort()).toEqual([...paletteRoles].sort());
  });

  test('round-trips ARGB and hex records', () => {
    const palette = Palette.from(0xff334157, {backgroundTone: 10, algo: Algo.wcag21});
    const captured = PaletteSnapshot.capture(palette);
    const fromRecord = PaletteSnapshot.fromRecord(captured.toRecord());
    const fromHex = PaletteSnapshot.fromHexRecord(captured.toHexRecord());
    expect(fromRecord.equals(captured)).toBe(true);
    expect(fromHex.equals(captured)).toBe(true);
    expect(fromHex.toHexRecord()).toEqual(captured.toHexRecord());
  });

  test('rejects incomplete records', () => {
    expect(() => PaletteSnapshot.fromRecord({})).toThrow(/Missing palette role/);
    expect(() => PaletteSnapshot.fromHexRecord({})).toThrow(/Missing palette role/);
  });
});
