# Improvement check (refactors only)

Helper referenced from `SKILL.md`. Apply when the diff is a refactor, restructure, rename, simplification, or "while I was here" cleanup — anything where the goal is to make existing code *better* rather than do something new.

A refactor is only worth keeping if it's actually better than what it replaced. Be honest, not flattering — see the "Honesty over politeness" section in user-CLAUDE.md. The default failure mode is to declare any change you wrote an improvement; resist that.

Compare against the pre-change baseline on the dimensions the refactor claimed to address:

- [ ] **Goal stated** — what was this refactor supposed to improve (readability, testability, fewer concepts, removed duplication, smaller surface)? Name it explicitly before judging.
- [ ] **Goal achieved** — on that specific dimension, is the after-state genuinely better than the before-state? Compare line count, indirection depth, number of concepts a reader has to hold, number of call sites that needed to change.
- [ ] **No regression on other dimensions** — did the refactor trade one problem for another? (e.g. removed duplication but introduced a leaky abstraction; renamed for clarity but broke grep-ability; split a long function but scattered related logic.)
- [ ] **Cost is paid for** — the diff size, the churn for reviewers, the risk of behavioral change. Is the win proportional?

Then write a one-line verdict, picking exactly one:

- ✅ **Improvement** — the refactor's stated goal was achieved without offsetting cost. Keep.
- ⚖ **Mixed** — partial win. Name what's better, what's worse, and propose: keep, revert the costly parts, or land a smaller scoped version.
- ❌ **Not an improvement** — the after-state isn't better than the before-state, or the cost outweighs the win. Propose reverting the diff (or the parts that didn't earn their keep).
- ❓ **Can't tell** — no clear baseline comparison possible (e.g. subjective readability with no measurable shift). Say so; don't default to ✅.

If the verdict is ⚖, ❌, or ❓, lead the final report with it. Don't bury an honest "this wasn't worth it" under the rest of the checklist.
