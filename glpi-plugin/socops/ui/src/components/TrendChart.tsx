import { formatShortDate } from '../lib/tickets';
import type { TrendPoint } from '../types';

interface TrendChartProps {
  points: TrendPoint[];
  onSelect?: (date: string) => void;
}

export function TrendChart({ points, onSelect }: TrendChartProps) {
  const width = 640;
  const height = 188;
  const margin = { top: 14, right: 12, bottom: 30, left: 24 };
  const values = points.map((point) => point.count);
  const max = Math.max(1, ...values);
  const plotWidth = width - margin.left - margin.right;
  const plotHeight = height - margin.top - margin.bottom;
  const coordinates = points.map((point, index) => ({
    ...point,
    x: margin.left + (points.length > 1 ? (index / (points.length - 1)) * plotWidth : plotWidth / 2),
    y: margin.top + plotHeight - (point.count / max) * plotHeight,
  }));
  const line = coordinates.map((point) => point.x + ',' + point.y).join(' ');
  const area =
    coordinates.length > 0
      ? margin.left +
        ',' +
        (height - margin.bottom) +
        ' ' +
        line +
        ' ' +
        (width - margin.right) +
        ',' +
        (height - margin.bottom)
      : '';

  if (points.length === 0) {
    return <div className="chart-empty">No daily ticket data is available.</div>;
  }

  return (
    <div className="trend-chart">
      <svg
        viewBox={'0 0 ' + width + ' ' + height}
        role="img"
        aria-label="Daily Sentinel incident tickets over the last fourteen days"
        preserveAspectRatio="none"
      >
        <title>Sentinel incident tickets by day</title>
        {[0, 0.5, 1].map((fraction) => {
          const y = margin.top + plotHeight * fraction;
          return (
            <g key={fraction}>
              <line className="chart-grid" x1={margin.left} x2={width - margin.right} y1={y} y2={y} />
              <text className="chart-axis" x="0" y={y + 4}>
                {Math.round(max * (1 - fraction))}
              </text>
            </g>
          );
        })}
        <polygon className="chart-area" points={area} />
        <polyline className="chart-line" points={line} />
        {coordinates.map((point) => (
          <g key={point.date}>
            <circle className="chart-point" cx={point.x} cy={point.y} r="4">
              <title>{formatShortDate(point.date) + ': ' + point.count + ' tickets'}</title>
            </circle>
            {onSelect ? (
              <circle
                className="chart-hit"
                cx={point.x}
                cy={point.y}
                r="12"
                tabIndex={0}
                role="button"
                aria-label={formatShortDate(point.date) + ', ' + point.count + ' tickets. Open incident queue.'}
                onClick={() => onSelect(point.date)}
                onKeyDown={(event) => {
                  if (event.key === 'Enter' || event.key === ' ') onSelect(point.date);
                }}
              />
            ) : null}
          </g>
        ))}
        {coordinates.map((point, index) =>
          index % 3 === 0 || index === coordinates.length - 1 ? (
            <text key={point.date + '-label'} className="chart-axis chart-axis--date" x={point.x} y={height - 5}>
              {formatShortDate(point.date)}
            </text>
          ) : null,
        )}
      </svg>
    </div>
  );
}
