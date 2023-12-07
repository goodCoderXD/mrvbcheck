#!/bin/bash

set -e
# set -x

source "vars.sh"
# Specify REPO= in here: the repo to run a vibe check on.
# Specify DIR= in here: the dir this bash file is located. Use absolute. do not
# end with slash.

# Check if a branch argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <branch>"
    exit 1
fi

echo "Cleaning up old vibechecks"
rm -rf /tmp/mrvbcheck-*

# Generate a random directory name
rand_dir="/tmp/mrvbcheck-$(tr -dc 'a-f0-9' < /dev/urandom | head -c 8)"

# Create the random directory
mkdir -p "$rand_dir"

echo "$rand_dir"

# Clone the repo with the specified branch
echo "Git Clone"
git clone --branch "$1" "$REPO" "$rand_dir" --quiet

# Move into the cloned directory
cd "$rand_dir"

# Get the list of changed files between the specified branch and main
changed_files=$(git diff --name-only origin/main.."$1")

unique_dirs=$(echo "$changed_files" | grep -oE "^packages/[^/]*" | sort -u)

echo "Create Venv"
python3 -m venv venv

# Activate the virtual environment
source venv/bin/activate

# Install pylint + dependencies
echo "Install vibe check dependencies"
pip install --quiet pylint darker radon vulture pyright flake8-eradicate ruff ansible-lint "attrs>=22"

# Create a virtual environment

for pkg in $unique_dirs; do
    if [[ "$pkg" = "packages/cld" ]]; then
        pip install --quiet -e "packages/clirq"
    fi
    pip install --quiet -e "$pkg"
done
pip install --quiet "attrs>=22" # ansible-lint and cdb depend on diff attrs
pip freeze

# check for dead code
git checkout "$1" --quiet
echo "== Vulture Checks =="
for file in $changed_files; do
    if echo "$file" | grep -q '\.py$'; then
        lines_changed="$(git diff --unified=0 "origin/main..$1" "$file" | grep -E "^\@\@.*\+.*\@\@" | cut -d' ' -f3 | cut -d',' -f1 | tr -d '+' | tr -d '-')"
        vulture "$file" | grep "$file:$(echo $lines_changed | paste -s -d "|"):" || true
    fi
done

# Get radon information on each changed file
echo "== Radon + Ansible linter Checks =="
mkdir -p "$rand_dir/.radon"
mkdir -p "$rand_dir/.ansible-check"
mkdir -p "$rand_dir/.shell-check"
mkdir -p "$rand_dir/.pyright"

pyrightconfig="$DIR/pyrightconfig.json"
cp "$pyrightconfig" "$rand_dir"

git checkout "$1" --quiet
for file in $changed_files; do
    file_hash="$(echo "$file" | md5sum | cut -f1 -d" ")"
    if echo "$file" | grep -q '\.py$'; then
        radon cc --json "$file" > "$rand_dir/.radon/target-$file_hash.json" || true
        pyright "$file" --outputjson > "$rand_dir/.pyright/target-$file_hash.json" || true
    fi
    if echo "$file" | grep -q 'ansible_source.*\.yml$'; then
        ansible-lint --offline  -p "$file" -f brief --nocolor 2>/dev/null 1> "$rand_dir/.ansible-check/target-$file_hash.log" || true
    fi
    if echo "$file" | grep -q '\.sh'; then
        shellcheck "$file" > "$rand_dir/.shell-check/target-$file_hash.log" || true
    fi
done

git checkout main --quiet
for file in $changed_files; do
    file_hash="$(echo "$file" | md5sum | cut -f1 -d" ")"
    if echo "$file" | grep -q '\.py$'; then
        radon cc --json "$file" > "$rand_dir/.radon/main-$file_hash.json"
        pyright "$file" --outputjson > "$rand_dir/.pyright/main-$file_hash.json" || true
    fi
    if echo "$file" | grep -q 'ansible_source.*\.yml$'; then
        ansible-lint --offline  -p "$file" -f brief --nocolor 2>/dev/null 1> "$rand_dir/.ansible-check/main-$file_hash.log" || true
    fi
    if echo "$file" | grep -q '\.sh'; then
        shellcheck "$file" > "$rand_dir/.shell-check/main-$file_hash.log" || true
    fi
done

echo "== Linter Checks =="

# Compare the jsons of the radon outputs
python "$DIR/radon_check.py" "$rand_dir/.radon"

# compare the outputs of the ansible files
python "$DIR/log_subtraction.py" "$rand_dir/.ansible-check"

# comare the outputs of the shell files
python "$DIR/log_subtraction.py" "$rand_dir/.shell-check"

python "$DIR/pyright_check.py" "$rand_dir/.pyright"

git checkout "$1" --quiet
# Run pylint on each changed file
pylintrc="$DIR/.pylintrc"

flake8_ignores="F401,E501"
for file in $changed_files; do
    if echo "$file" | grep -q '\.py$'; then
        darker --revision origin/main "$file" --lint "pylint --rclint=$pylintrc $file" || true
        darker --revision origin/main "$file" --lint "ruff check $file" || true
        darker --revision origin/main "$file" --lint "flake8 --eradicate-aggressive --ignore=$flake8_ignores $file " || true
    fi
    if echo "$file" | grep -q '\.sh'; then
        shellcheck "$file" || true
    fi
done


echo "VB_CHECK_DIR: $rand_dir"
