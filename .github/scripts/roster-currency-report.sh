#!/usr/bin/env bash
# Delivers one roster-currency verdict to a human.
#
# `swift-institute/.github#65` records the failure this avoids: a detector
# that reports by rewriting one issue body in place notifies nobody, keeps no
# history, and looks identical on a clean fleet and a burning one. So the
# title states the verdict and the count, the body states the current finding
# set, and a comment — the only form of delivery that actually notifies — is
# posted whenever the finding set changes state or membership.
#
# Reads: STATE (current|drift|unmeasured), RESULT (the check's result line),
# RUN (the run URL), findings.txt, and GH_TOKEN. Requires `issues: write`.
set -euo pipefail

LABEL="roster-currency"
FINDINGS="${FINDINGS:-findings.txt}"
REPOSITORY="${GITHUB_REPOSITORY:?}"

# Membership, not wording: a fingerprint over the sorted finding lines, so a
# reworded message is not mistaken for new drift and a genuinely new
# repository always is. The state is part of it, so current → unmeasured is a
# change even though both carry no findings.
fingerprint=$(
    { echo "$STATE"; sort "$FINDINGS" 2>/dev/null || true; } |
        shasum -a 256 | cut -c1-16
)

case "$STATE" in
current)
    title="roster currency: current"
    headline="\`Workspace.json\` agrees with a live discovery of the Institute organizations."
    ;;
drift)
    committed=$(grep -c 'not discovered on GitHub' "$FINDINGS" || true)
    discovered=$(grep -c 'missing from Workspace.json' "$FINDINGS" || true)
    title="roster drift: $((committed + discovered)) repositories — ${discovered} missing from Workspace.json, ${committed} listed but absent from GitHub"
    headline="Run \`swift run --package-path Application workspace inventory\` to regenerate, then commit the result."
    ;;
unmeasured)
    # Loudest of the three on purpose. A detector that stopped measuring
    # must not read like one that measured and found nothing — that
    # equivalence is the defect this whole capability exists to remove.
    title="roster currency: NOT MEASURED — the check could not run"
    headline="Currency was **not measured**. This is not a clean result; the roster's state is unknown."
    ;;
*)
    echo "unknown state: $STATE" >&2
    exit 1
    ;;
esac

body=$(
    cat <<EOF
<!-- roster-currency:${fingerprint} -->
**${RESULT}**

${headline}

Measured by \`workspace doctor --institute\` — [latest run](${RUN}).

$(if [ -s "$FINDINGS" ]; then
        echo '```'
        cat "$FINDINGS"
        echo '```'
    else
        echo "_No findings._"
    fi)

---

This body is replaced by each run and states only the **current** verdict.
The history is in the comments below: one is posted whenever the verdict or
the set of drifting repositories changes. A run that changes nothing is
silent by design — see \`swift-institute/.github#65\`.
EOF
)

# Idempotent: `gh issue list --label` fails outright when the label does not
# exist yet, which would make the very first run look like a delivery failure.
gh label create "$LABEL" --repo "$REPOSITORY" \
    --description "Workspace.json disagrees with a live discovery" \
    --color B60205 >/dev/null 2>&1 || true

number=$(gh issue list --repo "$REPOSITORY" --label "$LABEL" --state open \
    --limit 1 --json number --jq '.[0].number // empty')

if [ "$STATE" = "current" ] && [ -z "$number" ]; then
    echo "roster currency: current, and no tracking issue is open. Nothing to deliver."
    exit 0
fi

if [ -z "$number" ]; then
    number=$(gh issue create --repo "$REPOSITORY" --label "$LABEL" \
        --title "$title" --body "$body" --assignee "${ASSIGNEE:-coenttb}" |
        grep -o '[0-9]*$')
    echo "opened #${number}: ${title}"
    exit 0
fi

previous=$(gh issue view "$number" --repo "$REPOSITORY" --json body --jq .body |
    grep -o 'roster-currency:[0-9a-f]*' | head -1 | cut -d: -f2 || true)

gh issue edit "$number" --repo "$REPOSITORY" --title "$title" --body "$body"

if [ "$previous" = "$fingerprint" ]; then
    echo "#${number}: unchanged (${fingerprint}). Body refreshed, no comment."
    exit 0
fi

# An edit notifies nobody. This is the delivery.
gh issue comment "$number" --repo "$REPOSITORY" --body "$(
    cat <<EOF
**${title}**

${RESULT} — [run](${RUN})

$(if [ -s "$FINDINGS" ]; then
        echo '```'
        cat "$FINDINGS"
        echo '```'
    else
        echo "_No findings._"
    fi)
EOF
)"
echo "#${number}: changed ${previous:-none} → ${fingerprint}. Commented."

if [ "$STATE" = "current" ]; then
    gh issue close "$number" --repo "$REPOSITORY" \
        --comment "Currency is current again; closing. The next run reopens this if it drifts."
    echo "#${number}: closed."
fi
