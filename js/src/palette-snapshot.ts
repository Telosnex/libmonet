import {type Argb, argbFromHex, hexFromArgb} from './color.js';
import {type Palette, type PaletteRole, paletteRoles} from './palette.js';

export type PaletteSnapshotRecord = Record<PaletteRole, Argb>;
export type PaletteSnapshotHexRecord = Record<PaletteRole, string>;

/**
 * Materialized snapshot of a Palette's role outputs.
 *
 * Dart's PaletteSnapshot captures every lazily-computed Palette role at a point
 * in time. The JS version mirrors that behavior with immutable ARGB role data
 * and the same role getters used by Palette.
 */
export class PaletteSnapshot {
  private readonly roles: PaletteSnapshotRecord;

  private constructor(record: PaletteSnapshotRecord) {
    this.roles = Object.freeze({...record}) as PaletteSnapshotRecord;
  }

  static capture(palette: Pick<Palette, PaletteRole | 'toRecord'>): PaletteSnapshot {
    return new PaletteSnapshot(palette.toRecord());
  }

  static fromRecord(record: Record<string, Argb>): PaletteSnapshot {
    const out = {} as PaletteSnapshotRecord;
    for (const role of paletteRoles) {
      const value = record[role];
      if (value === undefined) throw new Error(`Missing palette role: ${role}`);
      out[role] = value;
    }
    return new PaletteSnapshot(out);
  }

  static fromHexRecord(record: Record<string, string>): PaletteSnapshot {
    const out = {} as PaletteSnapshotRecord;
    for (const role of paletteRoles) {
      const value = record[role];
      if (value === undefined) throw new Error(`Missing palette role: ${role}`);
      out[role] = argbFromHex(value);
    }
    return new PaletteSnapshot(out);
  }

  private get(role: PaletteRole): Argb { return this.roles[role]; }

  get background(): Argb { return this.get('background'); }
  get backgroundText(): Argb { return this.get('backgroundText'); }
  get backgroundFill(): Argb { return this.get('backgroundFill'); }
  get backgroundBorder(): Argb { return this.get('backgroundBorder'); }
  get backgroundHovered(): Argb { return this.get('backgroundHovered'); }
  get backgroundSplashed(): Argb { return this.get('backgroundSplashed'); }
  get backgroundHoveredFill(): Argb { return this.get('backgroundHoveredFill'); }
  get backgroundSplashedFill(): Argb { return this.get('backgroundSplashedFill'); }
  get backgroundHoveredText(): Argb { return this.get('backgroundHoveredText'); }
  get backgroundSplashedText(): Argb { return this.get('backgroundSplashedText'); }
  get backgroundHoveredBorder(): Argb { return this.get('backgroundHoveredBorder'); }
  get backgroundSplashedBorder(): Argb { return this.get('backgroundSplashedBorder'); }
  get color(): Argb { return this.get('color'); }
  get colorText(): Argb { return this.get('colorText'); }
  get colorIcon(): Argb { return this.get('colorIcon'); }
  get colorHovered(): Argb { return this.get('colorHovered'); }
  get colorSplashed(): Argb { return this.get('colorSplashed'); }
  get colorHoveredText(): Argb { return this.get('colorHoveredText'); }
  get colorSplashedText(): Argb { return this.get('colorSplashedText'); }
  get colorHoveredIcon(): Argb { return this.get('colorHoveredIcon'); }
  get colorSplashedIcon(): Argb { return this.get('colorSplashedIcon'); }
  get colorBorder(): Argb { return this.get('colorBorder'); }
  get colorHoveredBorder(): Argb { return this.get('colorHoveredBorder'); }
  get colorSplashedBorder(): Argb { return this.get('colorSplashedBorder'); }
  get fill(): Argb { return this.get('fill'); }
  get fillText(): Argb { return this.get('fillText'); }
  get fillIcon(): Argb { return this.get('fillIcon'); }
  get fillHovered(): Argb { return this.get('fillHovered'); }
  get fillSplashed(): Argb { return this.get('fillSplashed'); }
  get fillHoveredText(): Argb { return this.get('fillHoveredText'); }
  get fillSplashedText(): Argb { return this.get('fillSplashedText'); }
  get fillHoveredIcon(): Argb { return this.get('fillHoveredIcon'); }
  get fillSplashedIcon(): Argb { return this.get('fillSplashedIcon'); }
  get fillBorder(): Argb { return this.get('fillBorder'); }
  get fillHoveredBorder(): Argb { return this.get('fillHoveredBorder'); }
  get fillSplashedBorder(): Argb { return this.get('fillSplashedBorder'); }
  get text(): Argb { return this.get('text'); }
  get textHovered(): Argb { return this.get('textHovered'); }
  get textSplashed(): Argb { return this.get('textSplashed'); }
  get textHoveredText(): Argb { return this.get('textHoveredText'); }
  get textSplashedText(): Argb { return this.get('textSplashedText'); }

  toRecord(): PaletteSnapshotRecord {
    return {...this.roles};
  }

  toHexRecord(): PaletteSnapshotHexRecord {
    const out = {} as PaletteSnapshotHexRecord;
    for (const role of paletteRoles) out[role] = hexFromArgb(this.roles[role]);
    return out;
  }

  equals(other: PaletteSnapshot): boolean {
    return paletteRoles.every(role => this.roles[role] === other.roles[role]);
  }
}
