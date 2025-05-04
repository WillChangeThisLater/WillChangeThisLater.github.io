#!/bin/bash

set -euo pipefail

# Create a temporary directory
TEMP_DIR=$(mktemp -d)
echo "Temporary directory created at: $TEMP_DIR" >&2

# Cleanup function to stop the Jekyll server and remove temp directory
function cleanup {
    if [ -f .jekyll_server_pid ]; then
        JEKYLL_PID=$(cat .jekyll_server_pid)
        if kill -0 $JEKYLL_PID 2>/dev/null; then
            echo "Stopping Jekyll server..." >&2
            kill $JEKYLL_PID
            wait $JEKYLL_PID 2>/dev/null || true
        fi
        rm -f .jekyll_server_pid
    fi
    # Remove temporary directory
    rm -rf "$TEMP_DIR"
    echo "Temporary directory removed: $TEMP_DIR" >&2
}

# Register cleanup function to be called on script exit
trap cleanup EXIT

# Start the Jekyll server, if not already running
function start_server {
    # Install necessary dependencies
    gem install github-pages >&2
    if ! lsof -i:4000 -t >/dev/null; then
        echo "Starting Jekyll server..." >&2
        nohup jekyll serve &> /dev/null &
        JEKYLL_PID=$!
        echo $JEKYLL_PID > .jekyll_server_pid
    fi
}

# Function to take a screenshot of the specified page
function screenshot {
    local path=${1:-/}
    local filename=$(mktemp -u "$TEMP_DIR/screenshot_XXXXXX.png")

    start_server

    # Wait for server to be reachable
    until curl --output /dev/null --silent --fail http://localhost:4000${path}; do
        echo 'Waiting for Jekyll server to be ready...' >&2
        sleep 1
    done

    if [ -z "$path" ] || [ "$path" = "/" ]; then
        echo "Taking screenshot of root path..." >&2
        webshot --fullpage --url "http://localhost:4000" --path "$filename"
    else
        echo "Taking screenshot of ${path}..." >&2
        webshot --fullpage --url "http://localhost:4000/${path}" --path "$filename"
    fi

    echo "$filename"
}

main() {
	cat <<EOF
I have the following webpage:

$(tree)
$(files-to-prompt .)

Consider the main page screenshot below.

Improve the blog post layout. I think at a minimum I want
the posts to show up with a last modified date.

EOF
}

main | lm --imageFiles "$(screenshot)"
