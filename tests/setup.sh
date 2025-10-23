#!/bin/bash
# Test framework setup script

set -e

echo "Installing test dependencies..."

# Install bats-core
if ! command -v bats &> /dev/null; then
    npm install -g bats
    echo "✅ bats-core installed"
fi

# Install shellmock for mocking
if [[ ! -d tests/lib/shellmock ]]; then
    mkdir -p tests/lib
    git clone https://github.com/capitalone/bash_shell_mock.git tests/lib/shellmock
    echo "✅ shellmock installed"
fi

echo "Test framework setup complete!"
