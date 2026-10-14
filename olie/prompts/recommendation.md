# Related Improvements Discovery

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Shared detail: `~/git/olie/prompts/workflow-policy.md`.

## 1. Objective

Analyze card `{{ code }}` and its related codebase to identify small, directly related improvements that could reasonably be implemented alongside the requested changes.

The goal is to avoid creating future cards for closely related changes that can be completed now with minimal additional effort, without unnecessarily expanding the current card's scope.

## 2. Gather Context

1. Retrieve the card's complete context using the MCP OlieFlowAi by searching for the card code `{{ code }}`.
2. Identify the card's requirements, business rules, acceptance criteria, and intended behavior.
3. Inspect the relevant code, tests, dependencies, and related implementations to understand the existing behavior.
4. Trace the affected functionality far enough to identify equivalent components, related endpoints, shared flows, and adjacent business rules.
5. Base suggestions on actual findings in the card and codebase. Do not invent missing requirements or assume that an implementation is defective without supporting evidence.

Do not modify any code or implement suggestions during this analysis. The objective is to identify and evaluate opportunities, not to execute them.

## 3. Rules for Identifying Improvements

Suggest only improvements that are directly related to the card's scope.

### 3.1. Inclusion Criteria

Consider a suggestion when at least one of the following applies:

- It ensures consistent behavior between equivalent components or operations within the same feature.
- It addresses an inconsistency in the same business rule or functional flow.
- It handles a closely related edge case exposed by the current implementation.
- It updates a directly affected test, validation, request, response, or UI behavior that would otherwise remain inconsistent.
- It completes a small, natural part of the requested behavior that would otherwise require a separate card.
- It prevents a foreseeable regression in the exact functionality being changed.

For every suggestion, identify the specific code or behavior that supports it.

### 3.2. Exclusion Criteria

Do not suggest:

- Generic refactoring or architectural improvements.
- Modernization for its own sake.
- Changes unrelated to the card's requirements or affected functionality.
- Improvements based solely on personal preference or hypothetical future needs.
- Large changes disguised as small enhancements.
- Work that should clearly be tracked in a separate card.
- Changes that duplicate behavior already implemented correctly.
- Speculative changes based on code that has not been inspected sufficiently.
- Filling or syncing `en.json`. English translations are resolved later; do not expand the card with English locale work.

The fact that code is nearby, old, or imperfect does not automatically make it relevant to the current card.

### 3.3. Scope and Effort

Prefer small, low-risk changes that can be implemented and tested alongside the current task.

Evaluate the actual additional effort, dependencies, testing requirements, and regression risk—not just the number of files affected.

Use these classifications:

- **Small:** A localized change with low implementation and verification effort.
- **Medium:** A change affecting multiple related components or requiring additional tests or coordination, but still closely connected to the card.
- **Large:** A change with substantial implementation effort, broad impact, significant risk, or independent requirements. Do not recommend implementing it as part of the current card; list it under 'Não fazer agora'.

Do not expand the card's scope merely because an improvement is technically desirable.

## 4. Evaluate Each Suggestion

For every relevant opportunity, answer the following questions:

1. What specific improvement is possible?
2. What existing code or behavior demonstrates the opportunity?
3. Why is the improvement directly related to this card?
4. What exactly would need to change?
5. What is the estimated scope: small or medium?
6. Is it worth implementing now, or should it be deferred?
7. What testing or regression considerations apply?

Use the following decision criteria:

- **Yes:** Directly related, sufficiently supported by code evidence, proportionate in effort, and low enough in risk to implement alongside the card.
- **Maybe:** Related, but its value, effort, dependencies, or risk requires further investigation or a decision.
- **No:** Not appropriate for the current card. Include it under 'Não fazer agora' only if it is a meaningful finding that should be retained for future consideration.

Do not recommend an improvement simply because it is possible. Explain its practical benefit and why implementing it now is preferable to creating a separate card.

## 5. Response Format

Respond in English Markdown.

### Summary

Provide a brief assessment of whether meaningful, directly related improvements were identified.

### Suggestions

For each suggestion, use the following structure:

#### [Suggestion title]

- **Suggestion:** Describe the proposed change precisely.
- **Evidence in code:** Identify the relevant file, component, method, endpoint, test, or existing behavior. Include a line reference when available.
- **Relation to the card:** Explain the direct functional or business-rule relationship.
- **Scope:** Small / Medium.
- **Do it now:** Yes / Maybe.
- **Why:** Explain the expected benefit, additional effort, and relevant risks.
- **Tests:** Briefly identify the tests or verification needed, when applicable.

Order suggestions by relevance and expected benefit, prioritizing small, low-risk improvements.

Do not pad the response with weak suggestions. If several suggestions address the same underlying issue, consolidate them into a single actionable suggestion.

### Do not do now

List relevant findings that should remain outside the current card's scope.

For each item, briefly explain why it should be deferred, such as excessive effort, independent business requirements, broader impact, or insufficient justification.

Do not list unrelated imperfections merely to populate this section.

If no relevant deferred findings were identified, explicitly state that none were identified.

### Conclusion

End with one of the following conclusions:

- **Related improvements are worth considering now:** At least one well-supported suggestion is classified as Yes.
- **Related improvements exist, but they need a decision:** Relevant suggestions exist, but none is sufficiently justified for immediate inclusion.
- **No related improvements found:** No meaningful, directly related improvements were found beyond the card's existing requirements.

## 6. Final Constraints

- Do not implement changes, edit files, create commits, or modify the card during this analysis.
- Do not infer that a suggestion is necessary without inspecting the relevant implementation.
- Do not confuse an existing defect with an opportunity that belongs to the current card.
- Do not recommend changes that duplicate the card's acceptance criteria; focus on additional opportunities.
- Keep the analysis actionable, evidence-based, and proportional to the task.
- If the available context is insufficient to assess a potential improvement, explicitly state the limitation instead of presenting speculation as a finding.