"""Summarize real per-frame millisecond captures; never invent benchmark results."""
import argparse
import csv
import json
import math
from pathlib import Path


def summarize(frame_times):
    if len(frame_times) < 100:
        raise ValueError("At least 100 frame times are required for a 1% low")
    if any(not math.isfinite(t) or t <= 0.0 for t in frame_times):
        raise ValueError("Frame times must be finite, positive milliseconds")
    ordered = sorted(frame_times, reverse=True)
    slow_count = max(1, math.ceil(len(ordered) * 0.01))
    return {
        "frames": len(frame_times),
        "duration_seconds": sum(frame_times) / 1000.0,
        "average_fps": len(frame_times) * 1000.0 / sum(frame_times),
        "one_percent_low_fps": slow_count * 1000.0 / sum(ordered[:slow_count]),
        "worst_frame_ms": ordered[0],
    }


def read_capture(path, column):
    with path.open(encoding="utf-8-sig", newline="") as handle:
        sample = handle.read(4096)
        handle.seek(0)
        try:
            dialect = csv.Sniffer().sniff(sample, delimiters=",;\t")
        except csv.Error:
            dialect = csv.excel
        reader = csv.DictReader(handle, dialect=dialect)
        if not reader.fieldnames or column not in reader.fieldnames:
            raise ValueError(f"Missing millisecond column {column!r}; available: {reader.fieldnames}")
        values = []
        for row in reader:
            if not any(value for value in row.values()):
                continue
            try:
                values.append(float(row[column]))
            except (TypeError, ValueError) as error:
                raise ValueError(f"Invalid frame time on CSV row {reader.line_num}") from error
    return values


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    parser.add_argument("--column", default="ms", help="Column containing milliseconds per frame")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    try:
        report = summarize(read_capture(args.capture, args.column))
    except (OSError, ValueError) as error:
        parser.error(str(error))
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print(f"Frames: {report['frames']} | Duration: {report['duration_seconds']:.2f} s")
        print(f"Average: {report['average_fps']:.2f} FPS | 1% low: {report['one_percent_low_fps']:.2f} FPS")
        print(f"Worst frame: {report['worst_frame_ms']:.2f} ms")
        if report["duration_seconds"] < 60:
            print("Short capture: use at least 60 seconds for published comparisons.")


if __name__ == "__main__":
    main()
