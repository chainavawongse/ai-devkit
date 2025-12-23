# plugin Hook System

The plugin uses hooks to enforce quality checks and validate changes throughout the development workflow.

## Hook Overview

The plugin implements four strategic hooks:

1. **SessionStart** - Initialize environment, verify tools, show best practices
2. **PostToolUse (Write|Edit)** - Auto-run lint/format after file changes
3. **SubagentStop** - Validate tests/build after subagent completes work
4. **SessionEnd** - Intelligently suggest documentation updates when needed

## Available Hooks

### 1. SessionStart

**Hook Event:** `SessionStart` (triggered when Claude Code starts a new session)

**When:** Plugin initialization at session start

**Purpose:** Initialize the plugin environment and display available workflows

**Implementation:** `hooks/session-init.sh`

**Timeout:** 30 seconds

---

### 2. PostToolUse (Write|Edit)

**Hook Event:** `PostToolUse` with matcher `Write|Edit`

**When:** After any file is written or edited using Write or Edit tools

**Purpose:** Automatically run lint and format checks on changed files

**Implementation:** `hooks/run-lint-format.sh`

**Timeout:** 60 seconds

**Input:** Receives JSON via stdin with `tool_input.file_path`

**Behavior:**

- Finds the nearest `justfile` in the directory hierarchy
- Runs `just lint` if available
- Runs `just format` if available
- Gracefully skips if commands don't exist
- Provides helpful tips if checks fail

**Example Output:**

```
✓ Found justfile in: /path/to/module
→ Running lint...
✓ Lint passed
→ Running format check...
✓ Format check passed
✓ All checks passed for changes in /path/to/module
```

**On Failure:**

```
✗ Lint found issues
💡 Tip: Run 'cd /path/to/module && just lint' to see details
💡 Tip: Run 'cd /path/to/module && just lint-fix' if available
```

---

### 3. SubagentStop

**Hook Event:** `SubagentStop` (triggered when a subagent task completes)

**When:** After a subagent completes a task

**Purpose:** Validate that changes don't break the application

**Implementation:** `hooks/run-post-task-validation.sh`

**Timeout:** 120 seconds

**Input:** Receives JSON via stdin with `cwd` (current working directory)

**Exit Code Behavior:** Exit code 2 blocks the subagent from stopping and shows stderr to Claude

**Validation Steps:**

1. **Run Unit Tests** (`just test`)
   - Fast feedback on code correctness
   - Catches regressions immediately

2. **Run Build** (`just build`)
   - Ensures code compiles/bundles successfully
   - 60-second timeout for long builds

3. **Validate Dev Server** (`just dev`)
   - Starts dev server and checks it runs
   - 3-second startup validation
   - Automatically shuts down after check

**Example Output:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Post-Task Validation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Found justfile in: /path/to/module

Step 1: Running unit tests...
✓ Unit tests passed

Step 2: Checking build...
✓ Build successful

Step 3: Validating dev server startup...
→ Starting dev server...
✓ Dev server started successfully

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ All validations passed!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

### 4. SessionEnd

**Hook Event:** `SessionEnd` (triggered when Claude Code session ends)

**When:** At the end of every session (logout, /clear, exit, etc.)

**Purpose:** Intelligently review session changes and suggest documentation updates only when architectural or design changes were made

**Implementation:** `hooks/session-end-review.sh`

**Timeout:** 30 seconds

**Input:** Receives JSON via stdin with `reason` (clear, logout, prompt_input_exit, other)

**Exit Code Behavior:** Exit code 2 shows guidance to Claude about documentation updates

**Analysis Criteria:**

The hook checks for indicators that documentation might need updating:

1. **Architectural files modified** - Changes to files with "architecture", "design", "pattern", etc.
2. **New modules created** - Multiple new directories suggest new components
3. **Tooling changes** - Updates to package.json, pyproject.toml, justfile, CI/CD configs
4. **Significant code additions** - More than 500 lines added might indicate new patterns

**Smart Decision Making:**

✅ **Suggests documentation update for:**

- New architectural patterns introduced
- Significant design decisions made
- New modules or major components added
- Development tooling or workflow changes

❌ **Does NOT suggest documentation for:**

- Simple bug fixes
- Feature implementations using existing patterns
- Refactoring without architectural changes
- Test additions
- Minor code changes

**Example Output (when update needed):**

```
⚠  Potential documentation update needed

Indicators:
  • architectural files modified
  • significant code changes (634 lines added)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📝 Documentation Review Needed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Before ending this session, consider:

1. Review your changes:
   • Did you introduce NEW architectural patterns?
   • Did you make SIGNIFICANT design decisions?
   • Did you add NEW modules or major components?
   • Did you change development tooling or workflows?

2. If YES to any above:
   Ask the user: "Should I update the project documentation to
   reflect the architectural/design changes made in this session?"

3. If user confirms, update:
   • CLAUDE-architecture.md - For new architectural patterns
   • CLAUDE-patterns.md - For new coding conventions
   • Module CLAUDE.md - For new tooling or commands
   • justfile - For new development commands

Do NOT update documentation for:
   ✗ Simple feature implementations following existing patterns
   ✗ Bug fixes that don't change architecture
   ✗ Refactoring without pattern changes
   ✗ Test additions
   ✗ Minor code changes

💡 Remember: Code documents features. Documentation documents
   patterns, architecture, and design decisions.
```

**Example Output (when no update needed):**

```
✓ Session changes appear to be routine - no documentation update needed
  Criteria checked:
    • No architectural file changes
    • No significant new modules
    • No tooling changes
    • Code changes within normal scope
```

---

## Design Principles

### 1. Language Agnostic

All hooks rely on `justfile` commands, making them work across any tech stack:

- Python projects: `just lint` → `ruff check`
- TypeScript projects: `just lint` → `eslint`
- Go projects: `just lint` → `golangci-lint`

The hooks don't need to know the underlying tools—they just run the standardized commands.

### 2. Graceful Failure

Hooks check if commands exist before running them:

```bash
if just --list 2>/dev/null | grep -q "^  lint"; then
    # Run lint
else
    echo "No 'lint' command in justfile, skipping"
fi
```

This allows hooks to work even in projects without full tooling setup.

### 3. Hierarchical Justfile Discovery

Scripts search up the directory tree to find the nearest `justfile`:

```
/workspace
├── frontend/
│   ├── src/components/Button.tsx  ← edited here
│   └── justfile                    ← found and used
└── backend/
    └── justfile
```

This ensures the correct justfile is used even when editing nested files.

### 4. Helpful Feedback

When checks fail, hooks provide actionable tips:

- Command to run manually for details
- Suggestion to use `lint-fix` if available
- Context about which justfile was used

### 5. Non-Blocking vs Blocking

- **post-write**: Non-blocking (doesn't interrupt flow, just warns)
- **post-task**: Blocking (prevents bad code from proceeding)

This balances rapid development with quality gates.

---

## Integration with Justfiles

Hooks expect standard justfile recipe names:

### Required for post-write Hook

- `lint` - Run linter (optional but recommended)
- `format` - Format code (optional but recommended)

### Required for post-task Hook

- `test` - Run unit tests (fast)
- `build` - Build/compile project (optional)
- `dev` - Start development server (optional)

### Recommended Additional Recipes

- `lint-fix` - Auto-fix linting issues
- `test-integration` - Run integration tests
- `test-full` - Run all tests

See `skills/writing-justfiles/SKILL.md` for full justfile conventions.

---

## Troubleshooting

### Hook not running?

Check hook registration in `hooks/hooks.json`:

```json
{
  "description": "Plugin hooks",
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/run-lint-format.sh\"",
            "timeout": 60
          }
        ]
      }
    ]
  }
}
```

### Script not executable?

Make scripts executable:

```bash
chmod +x plugins/hooks/*.sh
```

### Justfile not found?

Hooks search up the directory tree. Ensure justfile exists in module directory or parent:

```bash
# Add justfile to module
cd /path/to/module
echo "default:\n\t@just --list" > justfile
```

### Dev server validation timing out?

Adjust timeout in `hooks/run-post-task-validation.sh`:

```bash
# Change from 3 seconds to 5 seconds
sleep 5
```

---

## Customization

### Disable Specific Hooks

Edit `hooks/hooks.json` and remove or comment out unwanted hooks.

### Adjust Hook Behavior

Edit the shell scripts in `hooks/`:

- `run-lint-format.sh` - Customize lint/format checks
- `run-post-task-validation.sh` - Customize validation steps

### Add Custom Hooks

Add new hooks to `hooks/hooks.json` following the pattern:

```json
{
  "custom-hook": {
    "description": "My custom validation",
    "command": "bash ${PLUGIN_ROOT}/scripts/my-script.sh",
    "blocking": false,
    "inject_output": true
  }
}
```

---

## Best Practices

1. **Always create justfiles** - Use `/setup` to set up justfiles
2. **Keep `just test` fast** - Only run unit tests, not integration tests
3. **Use `just build` for validation** - Catch compilation errors early
4. **Monitor hook output** - Pay attention to warnings and tips
5. **Fix issues promptly** - Don't accumulate lint/format violations

---

## Future Enhancements

Planned improvements:

- [ ] Smart caching to avoid redundant checks
- [ ] Parallel execution of validation steps
- [ ] Integration with pre-commit hooks
- [ ] Custom validation rules per project
- [ ] Metrics and reporting on hook execution
