#!/bin/bash

# Configuration - Edit these variables as needed
# Array of repository URLs to export from
GIT_REPO_URLS=(
    "https://github.com/carbon-language/carbon-lang.git"
    #"https://github.com/facebook/react.git"
    "https://github.com/facebook/pyrefly.git"
)
NUM_LOGS=9999999  # Number of logs to export
OUTPUT_DIR="XML_commit_messages"  # Output directory name

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
if [ ${#GIT_REPO_URLS[@]} -eq 0 ]; then
    echo -e "${RED}Error: GIT_REPO_URLS array is empty${NC}"
    exit 1
fi

if ! [[ "$NUM_LOGS" =~ ^[0-9]+$ ]] || [ "$NUM_LOGS" -lt 1 ]; then
    echo -e "${RED}Error: NUM_LOGS must be a positive integer${NC}"
    exit 1
fi

# Create output directory if it doesn't exist
if [ ! -d "$OUTPUT_DIR" ]; then
    echo -e "${YELLOW}Creating output directory: $OUTPUT_DIR${NC}"
    mkdir -p "$OUTPUT_DIR"
fi

echo -e "${YELLOW}Number of repositories to process:${NC} ${#GIT_REPO_URLS[@]}"
echo -e "${YELLOW}Number of logs to export per repository:${NC} $NUM_LOGS"
echo -e "${YELLOW}Output directory:${NC} $OUTPUT_DIR"
echo ""

# Process each repository
for i in "${!GIT_REPO_URLS[@]}"; do
    GIT_REPO_URL="${GIT_REPO_URLS[$i]}"
    REPO_INDEX=$((i + 1))
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Processing repository ${REPO_INDEX}/${#GIT_REPO_URLS[@]}: ${GIT_REPO_URL}${NC}"
    echo -e "${GREEN}========================================${NC}"

    # Extract repository name from URL
    REPO_NAME=$(basename "$GIT_REPO_URL" .git)
    CLONE_DIR="temp_${REPO_NAME}_$(date +%s)_$$"
    OUTPUT_FILE="$OUTPUT_DIR/${REPO_NAME}_commits.xml"

    echo -e "${GREEN}Step 1: Cloning repository...${NC}"
    if git clone "$GIT_REPO_URL" "$CLONE_DIR"; then
        echo -e "${GREEN}✓ Repository cloned successfully${NC}"
    else
        echo -e "${RED}✗ Failed to clone repository: $GIT_REPO_URL${NC}"
        echo -e "${YELLOW}Continuing with next repository...${NC}"
        continue
    fi

    echo ""
    echo -e "${GREEN}Step 2: Exporting logs...${NC}"

    # Change to the cloned directory
    cd "$CLONE_DIR" || {
        echo -e "${RED}✗ Failed to enter cloned directory${NC}"
        echo -e "${YELLOW}Continuing with next repository...${NC}"
        continue
    }

    # Hard passphrase to separate commits (not needed for XML, but keeping for reference)
    COMMIT_SEPARATOR="===COMMIT_BOUNDARY_$(date +%s)_${REPO_NAME}_SEPARATOR==="

    # Initialize XML output file
    cat > "../$OUTPUT_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<repository>
    <name>$REPO_NAME</name>
    <url>$GIT_REPO_URL</url>
    <commits>
EOF

    # Get commit hashes first
    echo -e "${YELLOW}Getting commit list...${NC}"
    COMMIT_HASHES=$(git log --no-merges --pretty=format:"%H" -n "$NUM_LOGS")

    if [ -z "$COMMIT_HASHES" ]; then
        echo -e "${RED}✗ No commits found in repository${NC}"
        cd ..
        rm -rf "$CLONE_DIR"
        echo -e "${YELLOW}Continuing with next repository...${NC}"
        continue
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
            
            # Get detailed commit info for XML format
            COMMIT_HASH_VAL=$(git log --no-merges --pretty=format:"%H" -n 1 "$COMMIT_HASH")
            AUTHOR_EMAIL=$(git log --no-merges --pretty=format:"%ae" -n 1 "$COMMIT_HASH")
            COMMIT_DATE=$(git log --no-merges --pretty=format:"%ad" --date=iso -n 1 "$COMMIT_HASH")
            COMMIT_MESSAGE=$(git log --no-merges --pretty=format:"%B" -n 1 "$COMMIT_HASH")
            
            # Append XML commit to file
            cat >> "../$OUTPUT_FILE" << EOF
        <commit>
            <hash>$COMMIT_HASH_VAL</hash>
            <author>$AUTHOR_EMAIL</author>
            <date>$COMMIT_DATE</date>
            <message><![CDATA[$COMMIT_MESSAGE]]></message>
        </commit>
EOF
        fi
    done
    
    # Close XML root elements
    cat >> "../$OUTPUT_FILE" << 'EOF'
    </commits>
</repository>
EOF

    echo ""
    echo -e "${GREEN}✓ Logs exported successfully${NC}"

    # Get actual number of commits exported (count commit elements)
    ACTUAL_LOGS=$(grep -c "<commit>" "../$OUTPUT_FILE" 2>/dev/null || echo "0")
    echo -e "${YELLOW}Exported ${ACTUAL_LOGS} commit(s) to ${OUTPUT_FILE}${NC}"

    # Show log format explanation
    echo ""
    echo -e "${YELLOW}XML format: repository with name, url, and commits containing hash, author email, date, commit message${NC}"
    echo ""
    echo -e "${YELLOW}Preview of XML structure:${NC}"
    if [ -f "../$OUTPUT_FILE" ]; then
        head -15 "../$OUTPUT_FILE" 2>/dev/null || echo "No logs available"
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
    echo -e "${GREEN}✓ Repository ${REPO_NAME} completed successfully!${NC}"
    echo -e "${YELLOW}Log file location:${NC} $(pwd)/$OUTPUT_FILE"
    
    if [ -f "$OUTPUT_FILE" ]; then
        TOTAL_LINES=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')
        echo -e "${YELLOW}Total lines in output:${NC} $TOTAL_LINES"
    fi
    echo ""
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All repositories processed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}Output directory:${NC} $(pwd)/$OUTPUT_DIR"

# Show summary of all generated files
if [ -d "$OUTPUT_DIR" ]; then
    echo -e "${YELLOW}Generated files:${NC}"
    for file in "$OUTPUT_DIR"/*.xml; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            lines=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
            commits=$(grep -c "<commit>" "$file" 2>/dev/null || echo "0")
            echo -e "${YELLOW}  - $filename${NC} ($lines lines, $commits commits)"
        fi
    done
else
    echo -e "${RED}No output directory found${NC}"
fi

echo ""
echo -e "${GREEN}✓ Multi-repository export completed successfully!${NC}"