# ZigView

A basic webview application built with Zig that displays a file browser interface.

## Features

- Cross-platform GUI using webview-zig
- File browser listing current directory
- Developer tools support (right-click inspect)
- Modern gradient UI design
- Interactive file items with hover effects

## Building

```bash
zig build
```

## Running

```bash
./zig-out/bin/zigview
```

## Project Structure

- `build.zig` - Build configuration
- `build.zig.zon` - Project dependencies
- `src/main.zig` - Main Zig application code
- `src/index.html` - HTML/CSS/JavaScript frontend

## Dependencies

- [webview-zig](https://github.com/thechampagne/webview-zig) - Webview library for Zig
- webview C library (statically linked)

## License

MIT
