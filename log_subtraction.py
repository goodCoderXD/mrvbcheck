import sys
import pathlib

log_path = pathlib.Path(sys.argv[1])


assert log_path.is_dir()

main = [target_logs.read_text() for target_logs in log_path.glob("main-*.log")]
target = [target_logs.read_text() for target_logs in log_path.glob("target-*.log")]

all_main_logs: list[str] = []
for main_log in main:
    all_main_logs.extend([_.strip() for _ in filter(None, main_log.split("\n"))])

all_target_logs: list[str] = []
for target_log in target:
    all_target_logs.extend([_.strip() for _ in filter(None, target_log.split("\n"))])

for non_main_log in set(all_target_logs) - set(all_main_logs):
    print(non_main_log)
