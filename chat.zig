const std = @import("std");

extern fn drawRect(x: f32, y: f32, width: f32, height: f32, r: u8, g: u8, b: u8) void;
extern fn drawText(x: f32, y: f32, ptr: [*]const u8, len: usize) void;
extern fn clearScreen() void;

const MaxMessages = 50;
const MaxMessageLength = 256;

const Message = struct {
    text: [MaxMessageLength]u8,
    length: usize,
    is_player: bool,  // true for player messages (right), false for responses (left)
};

var messages: [MaxMessages]Message = undefined;
var message_count: usize = 0;

// Input field state
var current_input: [MaxMessageLength]u8 = undefined;
var input_length: usize = 0;
var scroll_position: f32 = 0;  // How far we've scrolled up
const VISIBLE_HEIGHT: f32 = 320;  // Height of message area
const MESSAGE_HEIGHT: f32 = 30;   // Height of each message including spacing

export fn handleInput(ptr: usize, len: usize) void {
    var msg_len = len;
    if (input_length + msg_len > MaxMessageLength - 1) {
        msg_len = MaxMessageLength - 1 - input_length;
    }
    
    const source_ptr: [*]const u8 = @ptrFromInt(ptr);
    const source_slice = source_ptr[0..msg_len];
    
    @memcpy(current_input[input_length..input_length + msg_len], source_slice);
    input_length += msg_len;
    draw();
}

export fn handleEnter() void {
    if (input_length == 0) return;
    
    if (message_count < MaxMessages) {
        // Add player message
        var msg = &messages[message_count];
        @memcpy(msg.text[0..input_length], current_input[0..input_length]);
        msg.length = input_length;
        msg.is_player = true;
        message_count += 1;

        // Add response
        if (message_count < MaxMessages) {
            const response = "I got your message!";
            msg = &messages[message_count];
            @memcpy(msg.text[0..response.len], response);
            msg.length = response.len;
            msg.is_player = false;
            message_count += 1;
        }
    } else {
        // If max messages reached, shift messages up
        for (0..MaxMessages - 2) |i| {
            messages[i] = messages[i + 2];
        }
        message_count = MaxMessages - 2;
        
        // Add new messages at the end
        var msg = &messages[message_count];
        @memcpy(msg.text[0..input_length], current_input[0..input_length]);
        msg.length = input_length;
        msg.is_player = true;
        message_count += 1;

        const response = "I got your message!";
        msg = &messages[message_count];
        @memcpy(msg.text[0..response.len], response);
        msg.length = response.len;
        msg.is_player = false;
        message_count += 1;
    }
    
    // Clear input
    input_length = 0;
    draw();
}

export fn handleBackspace() void {
    if (input_length > 0) {
        input_length -= 1;
        draw();
    }
}
export fn handleScroll(delta: f32) void {
    const total_height = @as(f32, @floatFromInt(message_count)) * MESSAGE_HEIGHT;
    const max_scroll = @max(0, total_height - VISIBLE_HEIGHT);
    
    scroll_position = @max(0, @min(max_scroll, scroll_position + delta));
    draw();
}

export fn draw() void {
    clearScreen();
    
    // Draw chat background
    drawRect(10, 10, 300, 400, 240, 240, 240);  // Main background
    
    // Draw messages area with clipping rectangle
    drawRect(20, 20, 280, VISIBLE_HEIGHT, 255, 255, 255);  // White messages area
    
    // Draw input area
    drawRect(20, 350, 280, 40, 255, 255, 255);  // White input box
    drawRect(20, 350, 280, 2, 200, 200, 200);   // Top border
    
    // Draw current input
    if (input_length > 0) {
        drawText(30, 375, &current_input, input_length);
    }
    
    // Draw messages with scroll offset
    var base_y: f32 = 40 - scroll_position;
    for (0..message_count) |i| {
        const msg = messages[i];
        const text_width = @as(f32, @floatFromInt(msg.length)) * 8;
        
        // Only draw if message is in visible area
        if (base_y >= 20 and base_y <= 340) {
            const x: f32 = if (msg.is_player)
                280 - text_width
            else
                30;
                
            const bg_color: u8 = if (msg.is_player) 200 else 230;
            drawRect(x - 5, base_y - 15, text_width + 10, 25, bg_color, bg_color, bg_color);
            drawText(x, base_y, &msg.text, msg.length);
        }
        
        base_y += MESSAGE_HEIGHT;
    }
}

export fn init() void {
    draw();
}
