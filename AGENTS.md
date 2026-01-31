# Ralph Agent Instructions

## Overview

Ralph is an autonomous AI agent loop that runs AI coding tools (OpenCode, Claude Code, or others) repeatedly until all PRD items are complete. Each iteration is a fresh instance with clean context.

## Repository Structure

This repository contains:
- **Distribution files** in `ralph/` - The Ralph files that get deployed to other repos
- **Local installation** in `scripts/ralph/` - Ralph installed in this repo (for working on Ralph itself)
- **Development files** at root - For developing Ralph itself
- **Example flowchart** in `flowchart/` - Interactive visualization of how Ralph works

## Commands

```bash
# Run Ralph on this repo (local installation)
cd scripts/ralph && ./ralph.sh [max_iterations]

# Run the flowchart dev server
cd flowchart && npm run dev

# Build the flowchart
cd flowchart && npm run build
```

## Key Files

### Distribution Files (ralph/)
- `ralph.sh` - The bash loop that spawns fresh AI instances
- `doctor.sh` - Validation script to check installation health
- `install.sh` - Installation script for setting up Ralph in other repos
- `AGENTS.md` - Instructions given to each AI agent instance (copy of root CLAUDE.md)
- `prd.json.example` - Example PRD format for users
- `README.md` - User-facing documentation

These files get copied to `scripts/ralph/` (or custom location) when installing Ralph in a repo.

### Local Installation (scripts/ralph/)
- Copy of `ralph/` files, installed in this repo for working on Ralph itself

### Development Files (root)
- `CLAUDE.md` - Agent instructions for Claude Code working on Ralph itself
- `AGENTS.md` - This file - documentation about Ralph
- `plans/` - Working directory for Ralph runs on this repo
- `flowchart/` - Interactive React Flow diagram explaining how Ralph works

## Flowchart

The `flowchart/` directory contains an interactive visualization built with React Flow. It's designed for presentations - click through to reveal each step with animations.

To run locally:
```bash
cd flowchart
npm install
npm run dev
```

## Patterns

- Each iteration spawns a fresh AI instance (Amp or Claude Code) with clean context
- Memory persists via git history, `plans/progress.txt`, and `plans/prd.json`
- Stories should be small enough to complete in one context window
- Always update AGENTS.md with discovered patterns for future iterations
