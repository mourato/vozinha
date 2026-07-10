# Performance Profiling

## Overview

Performance profiling helps identify bottlenecks in your application before they become user-facing issues.

## Time Profiler

### Using Instruments Time Profiler

1. Open Instruments (`Cmd + Space`, type "Instruments")
2. Select "Time Profiler" template
3. Select your target process
4. Click Record and exercise the code path
5. Click Stop and analyze the call tree

### Interpreting Results

The call tree shows CPU time spent in each function:

| Column | Meaning |
|--------|---------|
| Self | Time spent in this function only |
| Children | Time in functions called by this |
| Total | Self + Children |
| Symbol | Function name |

### Profiling in Code

```swift
import os.signpost

let log = OSLog(subsystem: "com.meeting.assistant", category: "performance")

// Mark start and end of operation
signpost(log, name: "Processing", log: .default, signpostID: 1)
// ... perform work
signpost(log, name: "Processing", log: .default, signpostID: 1)
```

### Finding Hotspots

1. Sort by "Total Time" column
2. Look for functions with high self-time
3. Check for unexpected recursion
4. Identify repeated expensive operations

## Memory Profiling

### Allocations Instrument

Track memory allocations over time:

1. Select "Allocations" template
2. Record while exercising the app
3. Filter by your process
4. Watch for growth patterns

### Leaks Instrument

Automatic memory leak detection:

1. Select "Leaks" template
2. Run the app
3. Purple indicators show leak locations
4. Check "Cycles & Roots" for retain cycles

### Manual Memory Check

```swift
// Debug memory pressure
import Foundation

func logMemoryUsage() {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    
    if result == KERN_SUCCESS {
        let usedMB = Double(info.resident_size) / 1024 / 1024
        print("Memory used: \(String(format: "%.2f", usedMB)) MB")
    }
}
```

## Core Animation Performance

### Debugging Options

```swift
// In scheme environment variables
OS_ACTIVITY_MODE = disable

// Or programmatically
#if DEBUG
UserDefaults.standard.set(false, forKey: "OS_ACTIVITY_MODE")
#endif
```

### Color Blended Layers

- **Red**: Layers drawn multiple times (opaque flag missing)
- **Green**: Layers drawn once (optimized)

### Color Offscreen Rendered

- **Yellow**: Layers rendered offscreen (should be cached)

### Checklist

- [ ] Set `isOpaque = true` where possible
- [ ] Set `cornerRadius` only when needed
- [ ] Use `drawingGroup()` for complex rendering
- [ ] Avoid `aspectRatio` with flexible frames
- [ ] Use `drawingGroup()` for Core Graphics operations

## SwiftUI Performance

### Lazy Loading

```swift
// Use LazyVStack/LazyHStack for long lists
LazyVStack {
    ForEach(items) { item in
        ItemRow(item: item)
    }
}
```

### EquatableView

```swift
// Prevent unnecessary redraws
struct MyView: View, Equatable {
    let item: Item
    
    var body: some View {
        Text(item.name)
    }
}

// Usage
EquatableView(content: MyView(item: item))
```

### Performance Tips

1. Use `@StateObject` for reference types
2. Avoid mutating @State directly
3. Use `.id()` for items that should redraw
4. Profile with Instruments > Core Animation template

## See Also

- [Debugging Tools Guide](debugging-tools-guide.md)
- [Production Debugging](production-debugging.md)
