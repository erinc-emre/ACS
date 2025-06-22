#!/bin/bash

# Configuration - Edit these variables as needed
GIT_REPO_URL="https://github.com/carbon-language/carbon-lang.git"  # Replace with your repository URL
NUM_LOGS=100000000  # Number of logs to export
OUTPUT_FILE="git-logs.txt"  # Output file name

# Note: Each commit will be separated by a unique passphrase for easy parsing
# Format: COMMIT_DATA followed by SEPARATOR_LINE
# To parse later, split the file by the separator lines

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Git Repository Log Export Script${NC}"
echo "======================================="

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: git is not installed or not in PATH${NC}"
    exit 1
fi

# Validate configuration
if [ -z "$GIT_REPO_URL" ]; then
    echo -e "${RED}Error: GIT_REPO_URL is not set${NC}"
    exit 1
fi

if ! [[ "$NUM_LOGS" =~ ^[0-9]+$ ]] || [ "$NUM_LOGS" -lt 1 ]; then
    echo -e "${RED}Error: NUM_LOGS must be a positive integer${NC}"
    exit 1
fi

echo -e "${YELLOW}Repository:${NC} $GIT_REPO_URL"
echo -e "${YELLOW}Number of logs to export:${NC} $NUM_LOGS"
echo -e "${YELLOW}Output file:${NC} $OUTPUT_FILE"
echo ""

# Extract repository name from URL
REPO_NAME=$(basename "$GIT_REPO_URL" .git)
CLONE_DIR="temp_${REPO_NAME}_$(date +%s)"

echo -e "${GREEN}Step 1: Cloning repository...${NC}"
if git clone "$GIT_REPO_URL" "$CLONE_DIR"; then
    echo -e "${GREEN}✓ Repository cloned successfully${NC}"
else
    echo -e "${RED}✗ Failed to clone repository${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Step 2: Exporting logs...${NC}"

# Change to the cloned directory
cd "$CLONE_DIR" || {
    echo -e "${RED}✗ Failed to enter cloned directory${NC}"
    exit 1
}

# Hard passphrase to separate commits
COMMIT_SEPARATOR="===COMMIT_BOUNDARY_$(date +%s)_SEPARATOR==="

# Initialize output file
> "../$OUTPUT_FILE"

# Get commit hashes first
echo -e "${YELLOW}Getting commit list...${NC}"
COMMIT_HASHES=$(git log --no-merges --pretty=format:"%H" -n "$NUM_LOGS")

if [ -z "$COMMIT_HASHES" ]; then
    echo -e "${RED}✗ No commits found in repository${NC}"
    cd ..
    rm -rf "$CLONE_DIR"
    exit 1
fi

# Count total commits
TOTAL_COMMITS=$(echo "$COMMIT_HASHES" | wc -l | tr -d ' ')
echo -e "${YELLOW}Found ${TOTAL_COMMITS} commit(s) to process${NC}"

# Process commits one by one
COUNTER=0
echo "$COMMIT_HASHES" | while read -r COMMIT_HASH; do
    if [ -n "$COMMIT_HASH" ]; then
        COUNTER=$((COUNTER + 1))
        echo -ne "\r${YELLOW}Processing commit ${COUNTER}/${TOTAL_COMMITS}...${NC}"
        
        # Get detailed commit info
        COMMIT_INFO=$(git log --no-merges --pretty=format:"%H|%an|%ae|%ad|%s" --date=iso -n 1 "$COMMIT_HASH")
        
        # Append to file with separator
        {
            echo "$COMMIT_INFO"
            echo "$COMMIT_SEPARATOR"
        } >> "../$OUTPUT_FILE"
    fi
done

echo ""
echo -e "${GREEN}✓ Logs exported successfully${NC}"

# Get actual number of commits exported (count separators)
ACTUAL_LOGS=$(grep -c "$COMMIT_SEPARATOR" "../$OUTPUT_FILE" 2>/dev/null || echo "0")
echo -e "${YELLOW}Exported ${ACTUAL_LOGS} commit(s) to ${OUTPUT_FILE}${NC}"

# Show log format explanation
echo ""
echo -e "${YELLOW}Log format: HASH|AUTHOR_NAME|AUTHOR_EMAIL|DATE|COMMIT_MESSAGE${NC}"
echo -e "${YELLOW}Commit separator: ${COMMIT_SEPARATOR}${NC}"
echo ""
echo -e "${YELLOW}Preview of first commit:${NC}"
if [ -f "../$OUTPUT_FILE" ]; then
    head -2 "../$OUTPUT_FILE" 2>/dev/null || echo "No logs available"
    echo -e "${YELLOW}...${NC}"
fi

# Return to original directory
cd ..

echo ""
echo -e "${GREEN}Step 3: Cleaning up...${NC}"
if rm -rf "$CLONE_DIR"; then
    echo -e "${GREEN}✓ Temporary directory cleaned up${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Failed to clean up temporary directory: $CLONE_DIR${NC}"
fi

echo ""
echo -e "${GREEN}✓ Script completed successfully!${NC}"
echo -e "${YELLOW}Log file location:${NC} $(pwd)/$OUTPUT_FILE"
echo -e "${YELLOW}Total commits exported:${NC} $(wc -l < "$OUTPUT_FILE" | tr -d ' ')"