import json
import sys


def load_json(stream: object) -> object:
    try:
        return json.load(stream)
    except json.JSONDecodeError:
        return {}


def walk(obj):
    if isinstance(obj, dict):
        for key, value in obj.items():
            if key.endswith("issues") and isinstance(value, dict):
                for name in ("warningSummaries", "errorSummaries"):
                    if name in value and value[name]:
                        yield from value[name]
            yield from walk(value)
    elif isinstance(obj, list):
        for item in obj:
            yield from walk(item)


def main() -> None:
    issues = list(walk(load_json(sys.stdin)))[:20]
    for issue in issues:
        print("-", issue.get("message", "").strip())


if __name__ == "__main__":
    main()

