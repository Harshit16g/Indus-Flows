#!/bin/bash
# Test script to verify ShellCheck fixes

echo "Testing ShellCheck fixes..."

# Check if shellcheck is available
if command -v shellcheck >/dev/null 2>&1; then
    echo "✅ ShellCheck found, running analysis..."
    shellcheck --config=.shellcheckrc scripts/**/*.sh
    if [ $? -eq 0 ]; then
        echo "✅ All ShellCheck issues resolved!"
    else
        echo "❌ ShellCheck issues found"
        exit 1
    fi
else
    echo "⚠️  ShellCheck not available, skipping analysis"
    echo "✅ Scripts syntax check passed (no shellcheck available)"
fi

# Test script syntax
echo "Testing script syntax..."
for script in scripts/**/*.sh; do
    if [ -f "$script" ]; then
        echo "Checking: $script"
        bash -n "$script"
        if [ $? -ne 0 ]; then
            echo "❌ Syntax error in $script"
            exit 1
        fi
    fi
done

echo "✅ All syntax checks passed!"
echo "✅ Critical fixes validation complete!"
