# Established patterns (GoF and friends)

Helper referenced from `SKILL.md`. Apply when the change introduces non-trivial structure — new classes, new abstractions, a new control-flow shape. Naming a known pattern makes the intent legible to future readers, but only use a pattern when it earns its keep; don't shoehorn one in.

## Creational
- [ ] **Factory / Factory Method** — for creating objects whose concrete type varies (instead of `new` scattered across callers)
- [ ] **Builder** — for objects with many optional parameters or staged construction
- [ ] **Singleton** — only for genuinely global state (config, connection pool); usually a code smell otherwise

## Structural
- [ ] **Adapter** — when bridging two incompatible interfaces (especially at integration boundaries)
- [ ] **Decorator** — when adding behavior to an object without changing its interface (logging, caching, retries)
- [ ] **Facade** — when wrapping a tangled subsystem behind a simpler API
- [ ] **Proxy** — for lazy loading, access control, or remote-call wrapping

## Behavioral
- [ ] **Strategy** — when you have multiple interchangeable algorithms (instead of long if/else or switch on type)
- [ ] **Observer / Pub-Sub** — when one change should fan out to many listeners
- [ ] **Command** — when actions need to be queued, logged, or undoable
- [ ] **Template Method** — when steps are fixed but specific actions vary by subclass
- [ ] **State** — when behavior changes meaningfully based on an internal mode (instead of switch on `this.status`)
- [ ] **Iterator** — use the language's built-in iteration protocol rather than hand-rolling traversal

## Anti-patterns to flag
- [ ] God object / god function (one thing doing everything)
- [ ] Switch-on-type chains that should be polymorphism or Strategy
- [ ] Shotgun surgery (one logical change requires edits in many files — usually a missing abstraction)
- [ ] Primitive obsession (passing raw strings/ints where a small value type would clarify intent)
