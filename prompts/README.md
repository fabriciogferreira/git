# Prompts

Prompts pasted into coding agents for the projects we work on. They are not Cursor rules for this meta-repo.

Every prompt is **English** and **Markdown**.

Do not translate text inside single quotes or `{{ }}`. Copy those spans as written. They are board labels, field names, and placeholders, not prose.

```markdown
Move the card to 'Em progresso'. The code is {{card}}.
```

## Where a prompt applies

Deeper files are more specific. A deeper file adds rules. If two files disagree, the deeper file wins.

| Path | Applies to |
| --- | --- |
| `prompts/*.md` (except this README) | Every repository |
| `prompts/<company>/*.md` | That company |
| `prompts/<company>/<project>/*.md` | That project |
| `prompts/<company>/<project>/<repository>/*.md` | That repository |

`enterscience/olie/` is the only project folder so far. Add a repository folder only when a rule does not apply to the whole project.

A file whose title is a task (for example `clone-repos.md`) is a one-shot request. It does not become a rule for every repository.

Do not repeat the parent prompt. If a rule applies to more than one project in the same company, move it up to the company folder.

## How to write one

One file, one subject. Short Markdown:

1. Title = when to use it
2. What to deliver
3. Context the agent cannot see in the code (hosts, branch, where the command runs)
4. Required actions, in imperative sentences
5. Out of scope
6. Done when — the check, or say that it did not run

No persona ("you are a senior engineer"), no restating what the diff already shows, no table that another file already has.
