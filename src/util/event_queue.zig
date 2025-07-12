const std = @import("std");

const Thread = std.Thread;
const Mutex = std.Thread.Mutex;
const atomic = std.atomic;

const MidiMessage = @import("midi_message.zig").MidiMessage;

pub const InputEvent = struct {
    message: MidiMessage,
    timestamp: i64,

    pub fn init(message: MidiMessage) InputEvent {
        return .{
            .message = message,
            .timestamp = std.time.microTimestamp(),
        };
    }
};

pub const EventQueue = struct {
    items: []InputEvent,
    head: usize,
    tail: usize,
    size: usize,
    capacity: usize,
    mutex: Mutex,
    shutdown_flag: atomic.Value(bool),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, capacity: usize) !EventQueue {
        if (capacity == 0) return error.InvalidCapacity;
        const items = try allocator.alloc(InputEvent, capacity);
        var queue = EventQueue{
            .items = items,
            .head = 0,
            .tail = 0,
            .size = 0,
            .capacity = capacity,
            .mutex = Mutex{},
            .shutdown_flag = atomic.Value(bool).init(false),
            .allocator = allocator,
        };
        std.log.info("EventQueue initialized: capacity={}, items.len={}, ptr={*}", .{
            queue.capacity, queue.items.len, &queue 
        });
        return queue;
    }

    pub fn deinit(self: *EventQueue) void {
        self.allocator.free(self.items);
    }

    pub fn push(self: *EventQueue, event: InputEvent) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.shutdown_flag.load(.monotonic)) return;
        if (self.size >= self.capacity) {
            self.head = (self.head + 1) % self.capacity;
            self.size -= 1;
        }
        self.items[self.tail] = event;
        self.tail = (self.tail + 1) % self.capacity;
        self.size += 1;
        std.log.debug("push: head={}, tail={}, size={}, capacity={}", .{
            self.head, self.tail, self.size, self.capacity
        });
    }

    pub fn pop(self: *EventQueue) ?InputEvent {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.size == 0) return null;
        const ev = self.items[self.head];
        self.head = (self.head + 1) % self.capacity;
        self.size -= 1;
        std.log.debug("pop: head={}, tail={}, size={}, capacity={}", .{
            self.head, self.tail, self.size, self.capacity
        });
        return ev;
    }

    pub fn waitForEvent(self: *EventQueue, timeout_ms: u64) ?InputEvent {
        const start_time = std.time.milliTimestamp();
        while (true) {
            if (self.shutdown_flag.load(.monotonic)) return null;
            if (self.pop()) |event| {
                return event;
            }
            if (timeout_ms > 0) {
                const elapsed = std.time.milliTimestamp() - start_time;
                if (elapsed >= timeout_ms) return null;
            }
            std.time.sleep(1_000_000); // 1ms
        }
    }

    pub fn drain(self: *EventQueue, buffer: []InputEvent) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        const count = @min(self.size, buffer.len);
        for (buffer[0..count]) |*slot| {
            slot.* = self.items[self.head];
            self.head = (self.head + 1) % self.capacity;
        }
        self.size -= count;
        return count;
    }

    pub fn shutdown(self: *EventQueue) void {
        self.shutdown_flag.store(true, .monotonic);
    }
};
