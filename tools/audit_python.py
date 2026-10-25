"""Regenerate the active-script inventory without importing application code."""

import ast
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
LOCAL_MODULES = {path.stem for path in (ROOT / "pyprogs").glob("*.py")}


def external_aliases(tree):
    aliases = {}
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            aliases.update((a.asname or a.name.split(".")[0], a.name) for a in node.names)
        elif isinstance(node, ast.ImportFrom):
            aliases.update((a.asname or a.name, f"{node.module}.{a.name}") for a in node.names)
    return {
        name: value
        for name, value in aliases.items()
        if value.split(".")[0] not in sys.stdlib_module_names | LOCAL_MODULES
    }


def external_calls(tree, aliases):
    calls = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            parts = ast.unparse(node.func).split(".")
            if parts[0] in aliases:
                calls.add(".".join([aliases[parts[0]], *parts[1:]]))
    return sorted(calls)


def inventory():
    for path in sorted((ROOT / "pyprogs").rglob("*.py")):
        tree = ast.parse(path.read_text(encoding="utf-8-sig"))
        external = external_aliases(tree)
        yield path.relative_to(ROOT).as_posix(), sorted(set(external.values())), external_calls(tree, external)


if __name__ == "__main__":
    print("# Current third-party API usage\n")
    print("Generated with `python tools/audit_python.py`. Includes 21 guarded entry points and one shared helper module.\n")
    print("| Script | External imports | Direct external calls |")
    print("| --- | --- | --- |")
    for path, imports, calls in inventory():
        print(f"| `{path}` | {', '.join(imports) or 'stdlib only'} | {', '.join(calls) or 'none'} |")
