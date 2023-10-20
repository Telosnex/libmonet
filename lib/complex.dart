import 'dart:math' as math;

class Complex {
  double real;
  double imaginary;

  Complex(this.real, [this.imaginary = 0]);

  Complex operator +(Complex c) =>
      Complex(real + c.real, imaginary + c.imaginary);

  Complex operator -(Complex c) =>
      Complex(real - c.real, imaginary - c.imaginary);

  Complex operator *(Complex c) => Complex(
      real * c.real - imaginary * c.imaginary,
      imaginary * c.real + real * c.imaginary);

  Complex operator /(Complex c) {
    double denom = c.real * c.real + c.imaginary * c.imaginary;
    return Complex((real * c.real + imaginary * c.imaginary) / denom,
        (imaginary * c.real - real * c.imaginary) / denom);
  }

  Complex pow(double p) {
    double r = math.sqrt(real * real + imaginary * imaginary);
    double theta = math.atan2(imaginary, real);
    double magnitude = math.pow(r, p).toDouble();
    double arg = theta * p;

    double realPart = magnitude * math.cos(arg);
    double imagPart = magnitude * math.sin(arg);

    return Complex(realPart, imagPart);
  }

  String toString() {
    // ignore: unnecessary_string_interpolations
    if (imaginary == 0) return '${real.toString()}';
    if (imaginary >= 0) return '${real.toString()} + ${imaginary.toString()}i';
    return '${real.toString()} - ${imaginary.abs().toString()}i';
  }
}
