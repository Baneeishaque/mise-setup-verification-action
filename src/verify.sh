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
  echo "::error::$TOOL_NAME not defined in $MISE_TOML. Add $TOOL_NAME to [tools] section."
  exit 1
fi

# 3. Get expected version from mise.toml
EXPECTED_VERSION=$(grep "$TOOL_NAME" "$MISE_TOML" | head -1 | sed 's/.*"\([^"]*\)".*/\1/' | tr -d ' ')
if [ -z "$EXPECTED_VERSION" ]; then
  echo "::error::Could not parse $TOOL_NAME version from $MISE_TOML"
  exit 1
fi

# 4. Verify tool availability via mise
# Ensure we use the config file specified
TOOL_PATH=$(MISE_CONFIG_FILE="$MISE_TOML" mise which "$TOOL_NAME" 2>/dev/null) || {
   echo "::error::mise cannot find '$TOOL_NAME'. run 'mise install'?"
   exit 1
}

echo "✓ Found $TOOL_NAME at: $TOOL_PATH"

# 5. Verify tool path is within mise data directory
MISE_DATA_DIR="${MISE_DATA_DIR:-$HOME/.local/share/mise}"
# Allow for standard mise path or custom one if set, but checking strictly against data dir
if [[ ! "$TOOL_PATH" == "$MISE_DATA_DIR"* ]]; then
  echo "::error::$TOOL_NAME path ($TOOL_PATH) is not from mise directory ($MISE_DATA_DIR)."
  exit 1
fi

# 6. Execute version check
echo "Running version check: $VERSION_COMMAND"
read -r -a CMD <<< "$VERSION_COMMAND"
ACTUAL_VERSION_OUTPUT=$(MISE_CONFIG_FILE="$MISE_TOML" mise exec --verbose -- "${CMD[@]}" 2>&1)
echo "Output: $ACTUAL_VERSION_OUTPUT"

# 7. Check if output contains expected version
if [[ "$ACTUAL_VERSION_OUTPUT" != *"$EXPECTED_VERSION"* ]]; then
    # Fallback: try to extract version like the bash script does for stricter check, but simple substring match is usually essentially correct if EXPECTED_VERSION is specific enough.
    # The bash script logic: grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
    # We will stick to the substring check but allow it to be an error if missing.
    echo "::error::Version output '$ACTUAL_VERSION_OUTPUT' does not contain expected '$EXPECTED_VERSION'."
    exit 1
else
    echo "✓ Version match confirmed ($EXPECTED_VERSION)."
fi

echo "::endgroup::"
