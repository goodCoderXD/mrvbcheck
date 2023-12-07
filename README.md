# MR Vibe Check

This is pretty customized for my work's monorepo.

Just runs a suite of tests over an MR that isn't part of the CI.
Most of it prone to false positives so that's why it's not in the CI.
Everytime I add these rules and ask people to add exceptions they shit the bed.
so I just read the output of this script and add it to my review.

A huge waste of time, ik. But w/o a human behind these requests nobody will
listen. Fuck even half the time no one even listens to the human too.

Not going to commit this at work because people are gonna get pissed.

Usage:

```sh
git clone https://github.com/goodCoderXD/mrvbcheck.git .

echo REPO="repo_path" >> vars.sh
echo DIR="$pwd" >> vars.sh

# then:
mrvibecheck.sh <branch name>
```
