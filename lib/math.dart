/// Returns 1 if num > 0, -1 if num < 0, and 0 if num = 0
int signum(double num) {
  if (num < 0) {
    return -1;
  } else if (num == 0) {
    return 0;
  } else {
    return 1;
  }
}

/// Linear interpolation between [start] and [stop] by [amount].
/// [amount] between 0 and 1, inclusive.
double lerp(double start, double stop, double amount) {
  assert(amount >= 0.0 && amount <= 1.0);
  return (1.0 - amount) * start + amount * stop;
}
