const std = @import("std");

extern fn drawRect(x: f32, y: f32, width: f32, height: f32, r: u8, g: u8, b: u8) void;
extern fn drawText(x: f32, y: f32, ptr: [*]const u8, len: usize) void;
extern fn clearScreen() void;
extern fn getMouseY() i32;

const MaxMessages = 50;
const MaxMessageLength = 256;
const MAX_LINE_WIDTH: f32 = 220;
const CHAR_WIDTH: f32 = 8;
const VISIBLE_HEIGHT: f32 = 320;
const INPUT_AREA_HEIGHT: f32 = 40;
const INPUT_BASE_Y: f32 = 350;
const MAX_INPUT_HEIGHT: f32 = 200;
const LINE_HEIGHT: f32 = 20;
const TEXT_PADDING: f32 = 10;

const Message = struct {
    text: [MaxMessageLength]u8,
    length: usize,
    is_player: bool,
};

var messages: [MaxMessages]Message = undefined;
var message_count: usize = 0;
var current_input: [MaxMessageLength]u8 = undefined;
var input_length: usize = 0;
var scroll_position: f32 = 0;
var input_scroll: f32 = 0;

fn getMessageHeight(text: []const u8) f32 {
    var lines: usize = 1;
    var line_width: f32 = 0;
    var word_width: f32 = 0;
    
    for (text) |char| {
        if (char == ' ') {
            line_width += word_width + CHAR_WIDTH;
            word_width = 0;
            
            if (line_width > MAX_LINE_WIDTH) {
                lines += 1;
                line_width = 0;
            }
        } else {
            word_width += CHAR_WIDTH;
            
            if (line_width + word_width > MAX_LINE_WIDTH) {
                lines += 1;
                line_width = word_width;
                word_width = 0;
            }
        }
    }
    
    if (word_width > 0) {
        if (line_width + word_width > MAX_LINE_WIDTH) {
            lines += 1;
        }
    }
    
    return @as(f32, @floatFromInt(lines)) * LINE_HEIGHT;
}

fn drawWrappedText(text: []const u8, x: f32, y: f32, is_right: bool) f32 {
    var current_line: [MaxMessageLength]u8 = undefined;
    var line_length: usize = 0;
    var lines: usize = 0;
    var current_y = y;
    
    for (text) |char| {
        current_line[line_length] = char;
        line_length += 1;
        
        const line_width = @as(f32, @floatFromInt(line_length)) * CHAR_WIDTH;
        if (line_width > MAX_LINE_WIDTH or char == '\n') {
            var wrap_pos = line_length;
            while (wrap_pos > 0) : (wrap_pos -= 1) {
                if (current_line[wrap_pos - 1] == ' ') break;
            }
            if (wrap_pos == 0) wrap_pos = line_length;
            
            const line_x = if (is_right) x - (@as(f32, @floatFromInt(wrap_pos)) * CHAR_WIDTH) else x;
            drawText(line_x, current_y, &current_line, wrap_pos);
            
            if (wrap_pos < line_length) {
                const remaining = line_length - wrap_pos;
                @memcpy(current_line[0..remaining], current_line[wrap_pos..line_length]);
                line_length = remaining;
            } else {
                line_length = 0;
            }
            
            current_y += LINE_HEIGHT;
            lines += 1;
        }
    }
    
    if (line_length > 0) {
        const line_x = if (is_right) x - (@as(f32, @floatFromInt(line_length)) * CHAR_WIDTH) else x;
        drawText(line_x, current_y, &current_line, line_length);
        lines += 1;
    }
    
    return @as(f32, @floatFromInt(lines)) * LINE_HEIGHT;
}

fn scrollToBottom() void {
    var total_height: f32 = 0;
    for (0..message_count) |i| {
        const msg = messages[i];
        total_height += getMessageHeight(msg.text[0..msg.length]) + 10;
    }
    
    const input_height = if (input_length > 0)
        @min(getMessageHeight(current_input[0..input_length]) + TEXT_PADDING, MAX_INPUT_HEIGHT)
    else
        INPUT_AREA_HEIGHT;
    
    const visible_height = INPUT_BASE_Y - input_height + INPUT_AREA_HEIGHT - 20;
    scroll_position = @max(0, total_height - visible_height + 20);
}

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
        var msg = &messages[message_count];
        @memcpy(msg.text[0..input_length], current_input[0..input_length]);
        msg.length = input_length;
        msg.is_player = true;
        message_count += 1;

        if (message_count < MaxMessages) {
            const response = "I got your message!";
            msg = &messages[message_count];
            @memcpy(msg.text[0..response.len], response);
            msg.length = response.len;
            msg.is_player = false;
            message_count += 1;
        }
    } else {
        for (0..MaxMessages - 2) |i| {
            messages[i] = messages[i + 2];
        }
        message_count = MaxMessages - 2;
        
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
    
    input_length = 0;
    scrollToBottom();
    draw();
}

export fn handleBackspace() void {
    if (input_length > 0) {
        input_length -= 1;
        draw();
    }
}

export fn handleScroll(delta: f32) void {
    const mouse_y = @as(f32, @floatFromInt(getMouseY()));
    const text_height = if (input_length > 0) 
        getMessageHeight(current_input[0..input_length])
    else 
        0;
    const input_height = @min(text_height + TEXT_PADDING, MAX_INPUT_HEIGHT);
    const input_y = INPUT_BASE_Y - (input_height - INPUT_AREA_HEIGHT);
    
    const scroll_speed = delta / 5;

    if (mouse_y > input_y) {
        if (text_height > input_height - TEXT_PADDING) {
            const max_scroll = text_height - (input_height - TEXT_PADDING);
            input_scroll = @max(0, @min(max_scroll, input_scroll + scroll_speed));
        }
    } else {
        scroll_position = @max(0, scroll_position + scroll_speed);
        
        var total_height: f32 = 0;
        for (0..message_count) |i| {
            const msg = messages[i];
            total_height += getMessageHeight(msg.text[0..msg.length]) + 10;
        }
        const visible_height = INPUT_BASE_Y - input_height + INPUT_AREA_HEIGHT - 20;
        const max_scroll = @max(0, total_height - visible_height + 20);
        scroll_position = @min(scroll_position, max_scroll);
    }
    draw();
}

export fn draw() void {
    clearScreen();
    
    drawRect(10, 10, 300, 400, 240, 240, 240);
    drawRect(20, 20, 280, VISIBLE_HEIGHT, 255, 255, 255);
    
    var input_bg_height = INPUT_AREA_HEIGHT;
    var input_y = INPUT_BASE_Y;
    
    if (input_length > 0) {
        const text_height = getMessageHeight(current_input[0..input_length]);
        input_bg_height = @min(text_height + TEXT_PADDING, MAX_INPUT_HEIGHT);
        input_y = INPUT_BASE_Y - (input_bg_height - INPUT_AREA_HEIGHT);
    }
    
    const visible_chat_height = INPUT_BASE_Y - input_bg_height + INPUT_AREA_HEIGHT - 20;
    var base_y: f32 = 40 - scroll_position;
    
    for (0..message_count) |i| {
        const msg = messages[i];
        if (base_y >= 20 - 30 and base_y <= visible_chat_height) {
            const x: f32 = if (msg.is_player) 280 else 30;
            const bg_color: u8 = if (msg.is_player) 200 else 230;
            
            const msg_height = drawWrappedText(msg.text[0..msg.length], x, base_y, msg.is_player);
            const text_width = @min(@as(f32, @floatFromInt(msg.length)) * CHAR_WIDTH, MAX_LINE_WIDTH);
            const bg_x = if (msg.is_player) x - text_width - 10 else x - 5;
            
            drawRect(bg_x, base_y - 15, text_width + 10, msg_height + 10, bg_color, bg_color, bg_color);
            _ = drawWrappedText(msg.text[0..msg.length], x, base_y, msg.is_player);
        }
        
        const msg_height = getMessageHeight(msg.text[0..msg.length]);
        base_y += msg_height + 10;
    }

    drawRect(20, input_y, 280, input_bg_height, 255, 255, 255);
    drawRect(20, input_y, 280, 2, 200, 200, 200);
    
    if (input_length > 0) {
        _ = drawWrappedText(
            current_input[0..input_length],
            30,
            input_y + TEXT_PADDING - input_scroll,
            false
        );
    }
}

export fn init() void {
    draw();
}
