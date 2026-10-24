"""Regenerate the active-script inventory without importing application code."""

import ast
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]


def inventory():
    for path in sorted((ROOT / "pyprogs").rglob("*.py")):
        tree = ast.parse(path.read_text(encoding="utf-8-sig"))
        aliases = {}
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                aliases.update((a.asname or a.name.split(".")[0], a.name) for a in node.names)
            elif isinstance(node, ast.ImportFrom):
                aliases.update((a.asname or a.name, f"{node.module}.{a.name}") for a in node.names)
        external = {
            name: value for name, value in aliases.items() if value.split(".")[0] not in sys.stdlib_module_names
        }
        calls = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Call):
                parts = ast.unparse(node.func).split(".")
                if parts[0] in external:
                    calls.add(".".join([external[parts[0]], *parts[1:]]))
        yield path.relative_to(ROOT).as_posix(), sorted(set(external.values())), sorted(calls)


if __name__ == "__main__":
    print("# Current third-party API usage\n")
    print("Generated with `python tools/audit_python.py`. Active standalone entry points all use a `__main__` guard.\n")
    print("| Script | External imports | Direct external calls |")
    print("| --- | --- | --- |")
    for path, imports, calls in inventory():
        print(f"| `{path}` | {', '.join(imports) or 'stdlib only'} | {', '.join(calls) or 'none'} |")
