# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`cde` is an intelligent directory navigation tool that extends the `cd` command with fuzzy matching, history tracking, and PATH-based executable discovery. It consists of:

- **Python package** (`cde/`): Core logic for directory resolution and navigation
- **Bash integration** (`cde.sh`): Shell function that wraps the Python tool
- **Color utilities** (`bash/`): Terminal output formatting helpers

## Development Commands

### Testing
```bash
# Run all tests (uses tox)
tox

# Run specific test environments
tox -e tests    # Run pytest with doctests
tox -e lints    # Run linting tools

# Run pytest directly (from tox config)
py.test --cov=cde --doctest-modules --doctest-glob="*.test" --doctest-glob="*.tests"
```

### Linting
```bash
# Run all linters
tox -e lints

# Individual tools
black --check cde bin/cde bin/dot_cd
flake8 cde
mypy --ignore-missing-imports cde
```

### Installation
```bash
# Install in development mode
pip install -e .

# Install with extras
pip install -e .[testing]  # Include test dependencies
pip install -e .[docs]     # Include Sphinx for docs
```

## Architecture

### Core Components

**`cde/cde.py`**: Main navigation logic
- Hierarchical path matching: exact name → prefix → substring → PATH executables
- CSV-based history management with timestamps
- Multi-match resolution with numbered selection menus
- Custom exceptions: `ToDo` (not implemented), `TryAgain` (ambiguous matches)

**`cde/types.py`**: Specialized path collections
- `PossiblePaths`: Filters to existing filesystem paths
- `UniquePaths`: Deduplicates using `same_path()` logic  
- `Roots`: Manages hierarchical path relationships

**`cde/__main__.py`**: CLI interface
- Uses `pysyte.cli` for argument parsing
- Supports numeric selection (-0, -1, -2) for multiple matches
- History operations: add, complete, delete, purge

### Integration Layer

**`cde.sh`**: Bash wrapper function
- Sources color utilities from `bash/`
- Provides `cde` function as drop-in `cd` replacement
- Must be sourced, not executed directly

**`bin/cde`**: Python entry point
- Handles argument processing and error cases
- Integrates with bash through stdout directory output

## Testing Strategy

- **Doctests**: Embedded in `.test` and `.tests` files alongside source
- **pytest**: Configured with `ELLIPSIS` and `NORMALIZE_WHITESPACE` for doctests
- **Coverage**: Uses pytest-cov for test coverage reporting
- **Linting**: black, flake8, mypy for code quality

## Key Dependencies

- **pysyte**: Path handling, CLI parsing, iteration utilities (≥0.7.50)
- **boltons**: `iterutils.unique` for deduplication
- **pytest/tox**: Testing framework

## Development Notes

- History stored as CSV in user's home directory for persistence
- PATH integration allows navigation to directories containing executables
- Fuzzy matching uses increasing specificity levels to handle ambiguity
- Color output managed through bash utilities in `bash/` directory