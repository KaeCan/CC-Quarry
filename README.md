# Quarry Installation & Update System

### 1. Initial Installation on Turtle

On your turtle, download and run the install script:

```lua
wget https://raw.githubusercontent.com/KaeCan/CC-Quarry/refs/heads/main/install.lua install.lua
install quarry
```

Or specify a custom folder:

```lua
install my-quarry-folder
```

This will:
- Download all quarry files to the specified folder (or `./quarry/` if no folder is specified)
- Create default `allow.list`, `ignore.list`, and `quarry.config` if they don't exist
- If no folder is specified, installs to the current directory

### 2. Updating

To update to the latest version, run the install script with the same folder name:

```lua
install quarry
```

Or update a different folder:

```lua
install my-quarry-folder
```

The script will:
- Download and replace all code files with the latest versions
- Preserve your existing `allow.list`, `ignore.list`, and `quarry.config`
- Create default config files only if they don't already exist

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
- If you don't specify a folder, the script installs to the current directory
- You can install to multiple folders by running `install` with different folder names
