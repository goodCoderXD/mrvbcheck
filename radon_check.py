import sys
import json
import pathlib

radon_path = pathlib.Path(sys.argv[1])

assert radon_path.is_dir()

main = [
    json.loads(main_json.read_text()) for main_json in radon_path.glob("main-*.json")
]
target = [
    json.loads(target_json.read_text())
    for target_json in radon_path.glob("target-*.json")
]

complexity_comparison = {}
rank_comparison = {}
lineno_comparison = {}
files_got_worse = {}

ranks = list("ABCDEF")

for blob in main:
    for file_name in blob:
        for component in blob[file_name]:
            component_name = component["name"]
            key = f"{file_name}::{component['type']}::{component_name}"
            complexity_comparison[key] = component["complexity"]
            rank_comparison[key] = component["rank"]
            lineno_comparison[key] = component["lineno"]

for blob in target:
    for file_name in blob:
        for component in blob[file_name]:
            component_name = component["name"]
            key = f"{file_name}::{component['type']}::{component_name}"
            if component["complexity"] > complexity_comparison.get(key, 0):
                print(
                    f"COMPLEXITY INCREASED: {key} ({complexity_comparison.get(key, 'DNE')} -> {component['complexity']})"
                )

            if ranks.index(component["rank"]) < ranks.index(
                rank_comparison.get(key, "F")
            ):
                print(
                    f'!!!! RANK DROPPED: {key} ({component["rank"]} -> {rank_comparison.get(key, "DNE")})'
                )
