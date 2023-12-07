import sys
import json
import pathlib

radon_path = pathlib.Path(sys.argv[1])

assert radon_path.is_dir()


def try_load(payload: pathlib.Path):
    try:
        return json.loads(payload.read_text())
    except:
        return {"generalDiagnostics": []}


main = [try_load(main_json) for main_json in radon_path.glob("main-*.json")]
target = [try_load(target_json) for target_json in radon_path.glob("target-*.json")]

all_main_issues = {}

for main_blob in main:
    main_issues = main_blob["generalDiagnostics"]
    for target_issue in main_issues:
        all_main_issues.setdefault(target_issue["file"], [])
        all_main_issues[target_issue["file"]].append(target_issue)

all_target_issues = {}

for target_blob in target:
    target_issues = target_blob["generalDiagnostics"]
    for target_issue in target_issues:
        all_target_issues.setdefault(target_issue["file"], [])
        all_target_issues[target_issue["file"]].append(target_issue)

for target_file, target_issues in all_target_issues.items():
    if target_file not in all_main_issues:
        for target_issue in target_issues:
            print(
                f"{target_file}:{target_issue['range']['start']['line']}:{target_issue['range']['start']['character']}:{target_issue['rule']}:{target_issue['message']}"
            )
            print()
        continue
    for target_issue in target_issues:
        overlap = False
        for main_issue in all_main_issues[target_file]:
            if main_issue["message"] == target_issue["message"]:
                overlap = True
                break
        if overlap:
            print(
                f"{target_file}:{target_issue['range']['start']['line']}:{target_issue['range']['start']['character']}:{target_issue.get('rule', '?')}:{target_issue['message']}"
            )
            print()
