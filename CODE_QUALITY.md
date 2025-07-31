# 🚀 Code Quality & Development Standards

This project maintains high code quality standards through automated formatting, linting, and testing. All configurations are included in the repository and will be applied consistently across all environments.

## 📋 Code Quality Tools

### 🎨 **Black** - Code Formatter
- **Configuration**: `pyproject.toml` → `[tool.black]`
- **Line Length**: 88 characters
- **Auto-applied**: On save in VS Code

### 📦 **isort** - Import Organizer  
- **Configuration**: `pyproject.toml` → `[tool.isort]`
- **Profile**: Black compatible
- **Auto-applied**: On save in VS Code

### 🔍 **Flake8** - Linter
- **Configuration**: `.flake8`
- **Line Length**: 88 characters
- **Ignored Issues**: E203, W503, E501, W291, W293, E302, E305
- **Auto-checked**: Real-time in VS Code

### 🏷️ **MyPy** - Type Checker
- **Configuration**: `pyproject.toml` → `[tool.mypy]`
- **Mode**: Gradual typing (strict where applicable)

## 🛠️ Development Commands

### Quick Setup
```bash
# Use the Makefile for easy development
make setup-dev    # One-time setup
make format       # Format all code
make lint         # Check code quality
make check        # Run all checks
```

### Manual Commands
```bash
# Format code
cd backend && .venv/bin/python -m black . --line-length 88
cd backend && .venv/bin/python -m isort . --profile black

# Check code quality
cd backend && .venv/bin/python -m flake8 .
cd backend && .venv/bin/python -m mypy .
```

## ⚙️ VS Code Integration

The project includes VS Code settings (`.vscode/settings.json`) that:
- ✅ Auto-format on save
- ✅ Auto-organize imports
- ✅ Real-time linting
- ✅ Proper Python environment detection

## 🔧 Configuration Files

| File | Purpose |
|------|---------|
| `pyproject.toml` | Black, isort, mypy, pytest configuration |
| `.flake8` | Flake8 linting rules |
| `.vscode/settings.json` | VS Code editor settings |
| `.pre-commit-config.yaml` | Git pre-commit hooks |
| `Makefile` | Development automation |

## 📏 Code Standards

- **Line Length**: 88 characters (modern Python standard)
- **Import Order**: stdlib → third-party → first-party → local
- **Formatting**: Black (no configuration needed)
- **Docstrings**: Google style preferred
- **Type Hints**: Encouraged but not required everywhere

## 🚫 What NOT to Do

❌ **Don't** add these tools to `.gitignore`  
❌ **Don't** modify line length without team consensus  
❌ **Don't** bypass pre-commit hooks  
❌ **Don't** commit unformatted code  

## ✅ Benefits

✅ **Consistent code style** across all contributors  
✅ **Reduced code review time** (no style discussions)  
✅ **Automatic error detection** before commit  
✅ **Better code readability** and maintainability  
✅ **Professional development workflow**  

---

*This configuration ensures that all code follows the same standards regardless of who writes it or what editor they use.*
