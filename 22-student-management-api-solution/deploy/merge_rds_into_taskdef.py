#!/usr/bin/env python3
"""Fusiona QUARKUS_* / STUDENT_DB_PASSWORD desde rds-credentials.env hacia ecs-task-definition JSON."""
import json
import sys


def load_env(path):
    kv = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, _, v = line.partition("=")
            k, v = k.strip(), v.strip()
            if k.startswith("#"):
                continue
            kv[k] = v
    return kv


def main() -> None:
    if len(sys.argv) != 3:
        print("uso: merge_rds_into_taskdef.py <task-definition.json> <rds-credentials.env>", file=sys.stderr)
        sys.exit(2)
    json_path, cred_path = sys.argv[1], sys.argv[2]
    keys = ("QUARKUS_DATASOURCE_JDBC_URL", "QUARKUS_DATASOURCE_USERNAME", "STUDENT_DB_PASSWORD")
    kv = load_env(cred_path)
    if not any(k in kv and kv[k] for k in keys):
        return
    with open(json_path, encoding="utf-8") as f:
        d = json.load(f)
    env = d["containerDefinitions"][0].setdefault("environment", [])
    for k in keys:
        if k not in kv or not kv[k]:
            continue
        for e in env:
            if e.get("name") == k:
                e["value"] = kv[k]
                break
        else:
            env.append({"name": k, "value": kv[k]})
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(d, f, indent=2)


if __name__ == "__main__":
    main()
