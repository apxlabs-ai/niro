# Model Selection

Niro works as two agents, and each runs on its own model:

- **The developer agent** writes the fixes, so you set its model with the agent
  CLI's own mechanism — not `niro.yaml`.
- **The attacker agent** finds and proves the bugs. It uses Niro's own reasoning
  across three capability tiers, set in `niro.yaml`.

You don't have to set either — the defaults are sensible. Tune the developer
agent to change fix quality and cost, or the attacker agent to change how hard
Niro probes.

## The developer agent's model

The developer agent uses your selected agent CLI. Niro doesn't set its model;
use the agent CLI's own mechanism:

| Agent CLI | Set the model with |
| --- | --- |
| Claude Code | `ANTHROPIC_MODEL` |
| OpenAI Codex | Codex's own config |
| GitHub Copilot CLI | `COPILOT_MODEL` |

## The attacker agent's model

The attacker agent uses Niro's own reasoning across three tiers. Pin any of
them in `niro.yaml`'s `models:` block — all three slots are optional and
independent, so set only what you care about:

```yaml
models:
  high:   <model-name>   # most capable — novel test cases, hard exploits. Costs more.
  medium: <model-name>   # balanced default for most work.
  low:    <model-name>   # cheapest — routine checks where speed and cost beat depth.
```

Left unpinned, Niro picks a capable model per tier on its own — it does **not**
reuse the developer agent's model. This is the recommended path; Niro also
chooses the correct identifier form for your agent CLI and auth setup.

If you do pin a name, Niro uses it verbatim, so it must be the exact identifier
your agent CLI's provider accepts — the same name you'd pass to that CLI's own
`--model` flag.

### GitHub Copilot: identifier form and shared model

Copilot needs a little more care if you pin a name:

- **Identifier form depends on your auth path.** Native Copilot OAuth expects
  dot-form (`claude-opus-4.7`); BYOK expects hyphen-form (`claude-opus-4-7`).
  When unsure, omit the override and let Niro pick the right form.
- **BYOK is all-or-nothing.** It activates only when all three
  `COPILOT_PROVIDER_TYPE`, `COPILOT_PROVIDER_BASE_URL`, and
  `COPILOT_PROVIDER_API_KEY` are set. A partial set falls back to native OAuth —
  and to dot-form — so set all three or none.
- **Both agents share one model by default.** Because a BYOK provider serves a
  single model, the attacker agent falls back to the `COPILOT_MODEL` you set for
  the developer agent, for any tier you don't pin above. Pin `high` / `medium` /
  `low` to give the attacker agent its own model.
