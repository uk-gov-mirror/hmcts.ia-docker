#!/bin/bash

# Array of services to start
services=(
    "ia-case-api"
    "ia-case-documents-api"
    "ia-case-notifications-api"
    "ia-home-office-integration-api"
    "ia-case-payments-api"
)

# Function to create new tab and run commands
run_in_new_tab() {
    local service=$1
    osascript <<EOF
tell application "iTerm"
    tell current window
        create tab with default profile
        tell current session
            write text "cd \$IAC_FT_REPOS_PATH/${service}"
            write text "source \$IAC_FT_REPOS_PATH/ia-docker/iac-ft.env"
            write text "./gradlew clean bootrun --no-daemon"
        end tell
    end tell
end tell
EOF
}

# Main execution
for service in "${services[@]}"; do
    echo "Starting ${service}..."
    run_in_new_tab "$service"
    # Small delay to prevent overwhelming iTerm
    sleep 2
done

echo "All services have been started in new iTerm tabs." 