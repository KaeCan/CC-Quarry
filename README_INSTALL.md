# Quarry Installation & Update System

## Setup Instructions

### 1. Upload Files to GitHub

1. Create a GitHub repository for your quarry code
2. Upload all files to the repository (including `install.lua`)
3. Update `install.lua` line 11 with your repository URL:
   ```lua
   local REPO_BASE = "https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/"
   ```
   Replace `YOUR_USERNAME` and `YOUR_REPO` with your actual GitHub username and repository name.

### 2. Initial Installation on Turtle

On your turtle, download and run the install script:

```lua
wget https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.lua install.lua
install quarry
```

This will:
- Download all quarry files to `./quarry/`
- Create default `allow.list`, `ignore.list`, and `quarry.config` if they don't exist
- Preserve existing config files if they already exist

**Note:** The HTTP API must be enabled on your turtle for `wget` and `http.get()` to work.

### 3. Updating

To update to the latest version, simply run:

```lua
install quarry
```

The script will:
- Download and replace all code files with the latest versions
- Preserve your existing `allow.list`, `ignore.list`, and `quarry.config`
- Keep your customizations intact

## File Structure

After installation, your folder will contain:

```
quarry/
├── quarry.lua              # Main script
├── item_evaluator.lua      # Helper script
├── block_tag_logger.lua    # Helper script
├── item_tag_logger.lua     # Helper script
├── run_tests.lua           # Test runner
├── allow.list
├── ignore.list
├── quarry.config
├── modules/
│   ├── config.lua
│   ├── fuel.lua
│   ├── inventory.lua
│   ├── item_filter.lua
│   ├── logger.lua
│   ├── mining.lua
│   ├── persistence.lua
│   ├── turtle_tracker.lua
│   └── utils.lua
└── tests/
    ├── framework.lua
    ├── mocks.lua
    ├── test_fuel.lua
    ├── test_inventory.lua
    ├── test_item_filter.lua
    ├── test_tracker.lua
    └── test_utils.lua
```

## Usage

After installation:

```lua
cd quarry
quarry
```

Or with arguments:

```lua
cd quarry
quarry w:32 l:32 maxd:50
```

## Notes

- The install script uses `http.get()` which requires the HTTP API to be enabled
- Config files (`allow.list`, `ignore.list`, `quarry.config`) are never overwritten
