# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Package Overview

This is the `cde` Python package - the core logic for intelligent directory navigation. The package extends `cd` functionality with fuzzy matching, history tracking, and PATH-based executable discovery.

## Module Structure

### Core Logic
- **`cde.py`**: Main module containing the `cde()` function and directory resolution logic
  - Hierarchical matching: exact → prefix → contains → PATH executables
  - CSV-based history management with add/delete/purge operations
  - Custom exceptions: `ToDo`, `TryAgain` for error handling
  - Menu system for multiple match selection

### Entry Point
- **`__main__.py`**: CLI interface using `pysyte.cli`
  - Numeric arguments (-0, -1, -2) for selecting from multiple matches
  - History operations (add, complete, delete, purge)
  - Version and debug modes

### Type System
- **`types.py`**: Custom collection classes built on `pysyte.types.lists`
  - `PossiblePaths`: Filtered paths that exist on filesystem
  - `UniquePaths`: Paths with duplicate detection via `same_path()`
  - `Roots`: Hierarchical path management with parent/child relationships

### Utilities
- **`timings.py`**: Time handling utilities
  - `now()`: Current timestamp wrapper
  - `time_since()`: Human-readable time intervals

## Testing Files

Test files use `.test` and `.tests` extensions with embedded doctests:
- `cde.test`, `cde.tests` - Main logic tests
- `types.test` - Type system tests  
- `timings.test`, `timings.tests` - Time utility tests

## Key Dependencies

- **pysyte**: Path handling, CLI parsing, iteration utilities
- **boltons**: `iterutils.unique` for deduplication

## Development Notes

- Uses doctest format with ELLIPSIS and NORMALIZE_WHITESPACE options
- Exception classes provide structured error handling for ambiguous matches
- History stored as CSV for persistence across sessions
- PATH integration allows navigation to executable locations