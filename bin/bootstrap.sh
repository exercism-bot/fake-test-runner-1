#!/usr/bin/env sh

# Synopsis:
# Bootstrap a test runner repo

# Example:
# LANGUAGE=Ruby SLUG=ruby ./bin/bootstrap.sh

# If any required arguments is missing, print the usage and exit
if [ -z "${LANGUAGE}" ] || [ -z "${SLUG}" ]; then
    echo "usage: LANGUAGE=<language> SLUG=<slug> ./bin/bootstrap.sh"
    exit 1
fi

ORG="exercism"
REPO="${ORG}/${SLUG}-test-runner"
gh repo create --public --template https://github.com/${ORG}/generic-test-runner/ "${REPO}"

# Disable merge commits and rebase merges
gh api --method PATCH "/repos/${REPO}" -f "allow_merge_commit=false" -f "allow_rebase_merge=false"

# Update team permissions
gh api --method PUT "/orgs/${ORG}/teams/maintainers-admin/repos/${REPO}" -f "permission=maintain"
gh api --method PUT "/orgs/${ORG}/teams/${SLUG}/repos/${REPO}" -f "permission=push"

# Add repo to deploy secrets
REPO_ID=$(gh api "repos/${REPO}" --jq '.id')
gh api --method PUT "/orgs/${ORG}/actions/secrets/AWS_ECR_ACCESS_KEY_ID/repositories/${REPO_ID}"
gh api --method PUT "/orgs/${ORG}/actions/secrets/AWS_ECR_SECRET_ACCESS_KEY/repositories/${REPO_ID}"
gh api --method PUT "/orgs/${ORG}/actions/secrets/DOCKERHUB_PASSWORD/repositories/${REPO_ID}"
gh api --method PUT "/orgs/${ORG}/actions/secrets/DOCKERHUB_USERNAME/repositories/${REPO_ID}"

# Create ruleset for default branch
jq -n '{name: "Default branch", target: "branch", enforcement: "active", conditions: {ref_name: {include: ["~DEFAULT_BRANCH"], exclude:[]}}, rules:[{type: "pull_request", parameters: {dismiss_stale_reviews_on_push: false, require_code_owner_review: true,require_last_push_approval: false, required_approving_review_count: 0, required_review_thread_resolution: false}}]}' | gh api --method POST "/repos/${REPO}/rulesets" --input -

REPO_DIR=$(mktemp -d)
gh repo clone "${REPO}" "${REPO_DIR}"
cd "${REPO_DIR}"

for file in $(git grep --files-with-matches fake); do
    sed -i '' -e "s/fake/${SLUG}/g" "${file}"
done

for file in $(git grep --files-with-matches Fake); do
    sed -i '' -e "s/Fake/${LANGUAGE}/g" "${file}"
done

cd -