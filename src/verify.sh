#!/bin/bash
set -euo pipefail

# verify.sh
# Usage: ./verify.sh <mise_toml_path> <tool_name> <version_command>

MISE_TOML="${1:?mise.toml path required}"
TOOL_NAME="${2:?tool name required}"
VERSION_COMMAND="${3:?version command required}"

echo "::group::Verifying $TOOL_NAME via mise"

# 1. Check if mise.toml exists
if [ ! -f "$MISE_TOML" ]; then
  echo "::error::Configuration file not found: $MISE_TOML"
  exit 1
fi

# 2. Check if tool is defined in configuration
if ! grep -q "$TOOL_NAME" "$MISE_TOML"; then
  echo "::warning::$TOOL_NAME usually should be in $MISE_TOML, but proceeding to check availability."
fi

# 3. Verify tool availability via mise
if ! mise which "$TOOL_NAME" >/dev/null 2>&1; then
   echo "::error::mise cannot find '$TOOL_NAME'. run 'mise install'?"
   exit 1
fi

TOOL_PATH=$(mise which "$TOOL_NAME")
echo "✓ Found $TOOL_NAME at: $TOOL_PATH"

# 4. Execute version check
echo "Running version check: $VERSION_COMMAND"
ACTUAL_VERSION_OUTPUT=$(mise exec -- $VERSION_COMMAND 2>&1)
echo "Output: $ACTUAL_VERSION_OUTPUT"

# 5. Extract expected version (simple grep approach, can be brittle but sufficient for basic verification)
# We try to extract the version string from mise.toml for "tool = version" format
EXPECTED_VERSION=$(grep "^$TOOL_NAME" "$MISE_TOML" | head -1 | cut -d'=' -f2 | tr -d ' "')

if [ -n "$EXPECTED_VERSION" ]; then
    echo "Expected version around: $EXPECTED_VERSION"
    if [[ "$ACTUAL_VERSION_OUTPUT" != *"$EXPECTED_VERSION"* ]]; then
        echo "::warning::Version output '$ACTUAL_VERSION_OUTPUT' may not contain expected '$EXPECTED_VERSION'. Please verify manually if this is intended."
    else
        echo "✓ Version match confirmed."
    fi
else
    echo "Could not strictly parse expected version from toml, skipping strict string match."
fi

echo "::endgroup::"
