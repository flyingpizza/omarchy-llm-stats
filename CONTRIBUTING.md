# Contributing

Thanks for wanting to contribute to LLM Stats!

## Development

1. Clone the repo
2. Edit files directly
3. Test with `python3 collect.py`
4. Submit a pull request

## Testing

Run the collector locally:
```bash
python3 collect.py [--server-url URL] [--interval SECONDS]
```

Check the output is valid JSON with the expected fields.

## Code Style

- Python: standard library only, no dependencies
- JavaScript: ES5 compatible (for Quickshell compatibility)
- QML: follow Quickshell conventions
- Comments: explain WHY not WHAT

## License

By contributing, you agree to license your work under MIT.
