export function signum(value: number): -1 | 0 | 1 {
  if (value < 0) return -1;
  if (value === 0) return 0;
  return 1;
}

export function lerpDouble(start: number, stop: number, amount: number): number {
  if (amount < 0 || amount > 1) throw new RangeError('amount must be between 0 and 1, inclusive');
  return (1.0 - amount) * start + amount * stop;
}
