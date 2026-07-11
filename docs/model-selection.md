# Model Selection

Niro works as two personas, and each runs on its own model:

- **The developer** writes the fixes. It's your agent, so you set its model with
  the agent's own mechanism — not `niro.yaml`.
- **The attacker** finds the bugs and re-tests each fix. It's Niro's own
  reasoning, across three capability tiers, set in `niro.yaml`.

You don't have to set either — the defaults are sensible. Tune the developer to
change fix quality and cost, or the attacker to change how hard Niro probes.

## The developer's model

The developer is your agent. Niro doesn't set its model; use the agent's own
mechanism:

| Agent | Set the model with |
| --- | --- |
| Claude Code | `ANTHROPIC_MODEL` |
| OpenAI Codex | Codex's own config |
| GitHub Copilot CLI | `COPILOT_MODEL` |

## The attacker's model

The attacker is Niro's own reasoning, and it runs across three tiers. Pin any of
them in `niro.yaml`'s `models:` block — all three slots are optional and
independent, so set only what you care about:

```yaml
models:
  high:   <model-name>   # most capable — novel test cases, hard exploits. Costs more.
  medium: <model-name>   # balanced default for most work.
  low:    <model-name>   # cheapest — routine checks where speed and cost beat depth.
```

Left unpinned, Niro picks a capable model per tier on its own — it does **not**
reuse your agent's model. This is the recommended path; Niro also chooses the
correct identifier form for your agent and auth setup.

If you do pin a name, Niro uses it verbatim, so it must be the exact identifier
your agent's provider accepts — the same name you'd pass to that agent's own
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
- **Both personas share one model by default.** Because a BYOK provider serves a
  single model, the attacker falls back to the `COPILOT_MODEL` you set for the
  developer, for any tier you don't pin above. Pin `high` / `medium` / `low` to
  give the attacker its own model.
