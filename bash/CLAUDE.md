# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Directory Overview

This directory contains bash utilities for terminal color output and formatting. These are shell helper functions used across the cde project for consistent, colored terminal output.

## Files

### `colours.sh`
ANSI color code definitions for terminal output:
- Exports color variables with and without bash prompt escaping
- Two sets: `OTHER_*` (with `\[` `\]` escaping for PS1) and standard (without escaping)
- Full spectrum: RED, GREEN, BLUE, YELLOW, CYAN, MAGENTA, WHITE, GRAY variants
- Based on ANSI escape sequences standard

### `crayons.sh`
Color utility functions built on `colours.sh`:
- **Sourcing**: Auto-sources `colours.sh` if not already loaded
- **Core functions**:
  - `show_colour()`: Colorizes text with specified ANSI color
  - `show_colour_line()`: Adds newline after colored output
- **Convenience functions**:
  - `show_red()`, `show_green()`: Quick color output
  - `show_red_line()`, `show_green_line()`, `show_blue_line()`: Colored lines
  - `show_error()`: Red error output to stderr
  - `show_command()`: Blue-colored command display
  - `show_run_command()`: Display and execute command
- **Git integration**: `show_this_branch()` for branch visualization
- **Aliases**: `red_line`, `green_line`, `blue_line`, `show_pass`, `show_fail`

## Usage Pattern

1. Source `crayons.sh` (which auto-sources `colours.sh`)
2. Use convenience functions or direct `show_colour` with color variables
3. Functions accept both arguments and piped input

## Dependencies

- Standard bash utilities: `readlink`, `dirname`, `cat`, `printf`
- Git (for `show_this_branch` function)
- ANSI-compatible terminal for color display