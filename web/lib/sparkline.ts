/** SVG polyline `points` for a series, oldest first. Empty string when there is nothing to draw. */
export function polylinePoints(values: number[], width: number, height: number, pad = 2): string {
  if (values.length < 2) return "";
  const min = Math.min(...values), max = Math.max(...values);
  const span = max - min;
  const innerH = height - pad * 2;
  const x = (i: number) => (i / (values.length - 1)) * width;
  const y = (v: number) => (span === 0 ? height / 2 : pad + innerH - ((v - min) / span) * innerH);
  return values.map((v, i) => `${round(x(i))},${round(y(v))}`).join(" ");
}
const round = (n: number) => String(Math.round(n * 100) / 100);
