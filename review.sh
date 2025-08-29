#!/bin/bash
# Simple diff review script for Linux/WSL
# Usage: ./review.sh [options] or interactive mode

set -e

# Configuration
CLAUDE_PATH="${CLAUDE_PATH:-claude}"

echo "=== Diff Review Setup ==="

# Check if we're in a git repository
if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
    echo "❌ Not in a git repository"
    echo "Please navigate to a git repository and try again."
    exit 1
fi

echo "Repository: $(git rev-parse --show-toplevel)"

# Check if claude is available
if ! command -v "$CLAUDE_PATH" >/dev/null 2>&1; then
    echo "❌ Claude Code not found at: $CLAUDE_PATH"
    echo "Set CLAUDE_PATH environment variable or ensure claude is in PATH"
    exit 1
fi
echo ""

# Interactive mode if no arguments provided
if [[ $# -eq 0 ]]; then
    echo "Options: [Enter]=defaults, 1/2=uncommitted/branch, 3/4=quick/detailed, +text=context, h=help"
    read -p "Choice: " user_input
    
    # Show help if requested
    if [[ "$user_input" == "h" || "$user_input" == "help" ]]; then
        echo ""
        echo "=== Diff Review Help ==="
        echo ""
        echo "Defaults (just press Enter):"
        echo "  • Uncommitted changes"
        echo "  • Quick review mode"
        echo "  • No context"
        echo ""
        echo "Usage Examples:"
        echo "  [Enter]                    Use all defaults"
        echo "  2                          Branch changes, quick mode"
        echo "  4                          Uncommitted, detailed mode"
        echo "  24                         Branch changes, detailed mode"
        echo "  4This adds user auth       Uncommitted, detailed, with context"
        echo ""
        echo "Options:"
        echo "  1 = Uncommitted changes (default)"
        echo "  2 = Branch changes vs main/master"
        echo "  3 = Quick review - just results (default)"
        echo "  4 = Detailed review - show Claude's thinking"
        echo "  Text after numbers = context description"
        echo ""
        
        read -p "Choice: " user_input
    fi
    
    # Parse the input
    REVIEW_TYPE="uncommitted"  # default
    MODE="quick"              # default
    CONTEXT=""
    
    if [[ -n "$user_input" ]]; then
        # Extract digits and text
        if [[ "$user_input" =~ ^([12])?([34])?(.*?)$ ]]; then
            changes_type="${BASH_REMATCH[1]}"
            review_mode="${BASH_REMATCH[2]}"
            context_text="${BASH_REMATCH[3]}"
            
            # Set review type
            if [[ "$changes_type" == "2" ]]; then
                REVIEW_TYPE="branch"
            elif [[ "$changes_type" == "1" ]]; then
                REVIEW_TYPE="uncommitted"
            fi
            
            # Set mode
            if [[ "$review_mode" == "4" ]]; then
                MODE="detailed"
            elif [[ "$review_mode" == "3" ]]; then
                MODE="quick"
            fi
            
            # Set context (trim and limit)
            CONTEXT=$(echo "$context_text" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | cut -c1-500)
        fi
    fi
else
    # Command line arguments mode
    REVIEW_TYPE="${1:-uncommitted}"  # uncommitted or branch
    MODE="${2:-quick}"               # quick or detailed
    CONTEXT="${3:-}"                 # optional context

    # Validate arguments
    if [[ "$REVIEW_TYPE" != "uncommitted" && "$REVIEW_TYPE" != "branch" ]]; then
        echo "❌ Invalid review type: $REVIEW_TYPE (must be 'uncommitted' or 'branch')"
        exit 1
    fi

    if [[ "$MODE" != "quick" && "$MODE" != "detailed" ]]; then
        echo "❌ Invalid mode: $MODE (must be 'quick' or 'detailed')"
        exit 1
    fi
fi

echo "Options: $REVIEW_TYPE changes, $MODE mode"
if [[ -n "$CONTEXT" ]]; then
    echo "Context: $CONTEXT"
fi
echo ""

# Get the diff based on selection
if [[ "$REVIEW_TYPE" == "branch" ]]; then
    # Get default branch
    DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
    BASE=$(git merge-base "$DEFAULT_BRANCH" HEAD)
    
    DIFF=$(git diff "$BASE" HEAD)
    DESCRIPTION="branch changes (vs $DEFAULT_BRANCH)"
else
    # Show all uncommitted changes
    STAGED_DIFF=$(git diff --cached)
    UNSTAGED_DIFF=$(git diff)
    UNTRACKED_FILES=$(git ls-files --others --exclude-standard)
    
    DIFF=""
    if [[ -n "$STAGED_DIFF" ]]; then
        DIFF+="=== STAGED CHANGES ===$'\n'$STAGED_DIFF$'\n\n'"
    fi
    if [[ -n "$UNSTAGED_DIFF" ]]; then
        DIFF+="=== UNSTAGED CHANGES ===$'\n'$UNSTAGED_DIFF$'\n\n'"
    fi
    if [[ -n "$UNTRACKED_FILES" ]]; then
        DIFF+="=== UNTRACKED FILES ===$'\n'"
        while IFS= read -r file; do
            if [[ -f "$file" ]]; then
                DIFF+="New file: $file$'\n'"
                DIFF+="$(cat "$file")$'\n\n'"
            fi
        done <<< "$UNTRACKED_FILES"
    fi
    DESCRIPTION="all uncommitted changes (staged + unstaged + untracked)"
fi

if [[ -z "$DIFF" ]]; then
    echo "No $DESCRIPTION to review"
    exit 0
fi

# Check diff size and warn if large
LINE_COUNT=$(echo "$DIFF" | wc -l)
if [[ $LINE_COUNT -gt 300 ]]; then
    echo "⚠️  Large diff detected: $LINE_COUNT lines"
    read -p "Continue with review of $LINE_COUNT lines? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Review cancelled"
        exit 0
    fi
    echo ""
fi

# Build the review prompt with diff included
CONTEXT_SECTION=""
if [[ -n "$CONTEXT" ]]; then
    CONTEXT_SECTION=$'\n\nContext: '"$CONTEXT"$'\n'
fi

REVIEW_PROMPT="Please review this git diff as a merge request. It was made by my developer. You have access to the full repository context - feel free to examine related files, understand the broader codebase structure, and check how these changes fit into the overall architecture.$CONTEXT_SECTION

Focus on:
1. Code quality and best practices
2. Potential bugs or issues  
3. Security considerations
4. Performance implications
5. Documentation needs
6. Test coverage gaps
7. Integration with existing code (check related files if needed)
8. Consistency with codebase patterns and conventions

Feel free to:
- Examine files that are imported/referenced in the diff
- Check for similar patterns elsewhere in the codebase
- Verify that interfaces and contracts are properly maintained
- Look at tests related to the changed functionality
- Review documentation that might need updates

Provide constructive feedback and suggestions for improvement.

Here is the diff to review:

$DIFF"

echo "Reviewing $DESCRIPTION with Claude..."

# Run Claude with the diff included in the prompt in plan mode (read-only access)
if [[ "$MODE" == "detailed" ]]; then
    "$CLAUDE_PATH" --permission-mode plan "$REVIEW_PROMPT"
else
    "$CLAUDE_PATH" -p --permission-mode plan "$REVIEW_PROMPT"
fi