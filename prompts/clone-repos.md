# Clone every project repository

One-shot request for this meta-repo. Not a product coding rule. Do not repeat `prompts/agent.md`.

## Deliver

Every repository listed in the `projects/**/project.conf` files on disk, each in the path and on the branch `CLONE_REPOS` names. The agent can then read the code and write better prompts.

## Context

The list lives in each `project.conf` `CLONE_REPOS` entry: `"<url> <path-relative-to-~/git> [branch]"`. The helper that creates the parent directory, clones, and fast-forwards only when the checkout is already on the expected branch is `workvm_clone_project_repos` in `lib/git.sh`. Ids come from `workvm_list_project_ids`. Load both through `lib/common.sh`.

## Required

From `~/git`:

```bash
source lib/common.sh
while IFS= read -r id; do
  CLONE_REPOS=()
  # shellcheck disable=SC1090
  source "projects/$id/project.conf"
  workvm_clone_project_repos "${CLONE_REPOS[@]}"
done < <(workvm_list_project_ids projects)
```

- Create only the directories the clone path needs.
- If the checkout already exists on another branch, do not switch. Report the path and the current branch.
- If a clone fails (network, SSH), continue and list the failure at the end.

## Out of scope

- Do not run `project-setup.sh`. Do not create or change `~/.config/workvm/current`. Do not enable `workvm.service`.
- Do not run `docker compose`, `post-clone.sh`, or `docker run`.
- Do not apply the `files/` overlay and do not commit.

## Done when

Every `CLONE_REPOS` entry is a git repository at the expected path, or it is on the list of what could not be cloned and why. No container was created and no project was marked active on the VM.
