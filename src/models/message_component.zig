const std = @import("std");
const Snowflake = @import("snowflake.zig").Snowflake;
const Emoji = @import("guild.zig").Emoji;
const ChannelType = @import("channel.zig").ChannelType;

/// The type of a message component.
pub const ComponentType = enum(u8) {
    ActionRow = 1,
    Button = 2,
    StringSelect = 3,
    TextInput = 4,
    UserSelect = 5,
    RoleSelect = 6,
    MentionableSelect = 7,
    ChannelSelect = 8,
};

/// The style of a button component.
pub const ButtonStyle = enum(u8) {
    Primary = 1,
    Secondary = 2,
    Success = 3,
    Danger = 4,
    Link = 5,
};

/// A button message component.
pub const Button = struct {
    type: ComponentType = .Button,
    style: ButtonStyle,
    label: ?[]const u8 = null,
    emoji: ?Emoji = null,
    custom_id: ?[]const u8 = null,
    url: ?[]const u8 = null,
    disabled: bool = false,
};

/// An option for a select menu.
pub const SelectOption = struct {
    label: []const u8,
    value: []const u8,
    description: ?[]const u8 = null,
    emoji: ?Emoji = null,
    default: bool = false,
};

/// A select menu message component.
pub const SelectMenu = struct {
    type: ComponentType = .StringSelect,
    custom_id: []const u8,
    options: ?[]SelectOption = null,
    channel_types: ?[]ChannelType = null,
    placeholder: ?[]const u8 = null,
    min_values: ?u32 = null,
    max_values: ?u32 = null,
    disabled: bool = false,
};

/// A text input component (for modals).
pub const TextInput = struct {
    type: ComponentType = .TextInput,
    custom_id: []const u8,
    style: u8 = 1, // Short=1, Paragraph=2
    label: []const u8,
    min_length: ?u32 = null,
    max_length: ?u32 = null,
    required: bool = true,
    value: ?[]const u8 = null,
    placeholder: ?[]const u8 = null,
};

/// An action row (can hold up to 5 buttons, 1 select menu, or 1 text input).
pub const ActionRow = struct {
    type: ComponentType = .ActionRow,
    components: []MessageComponent,
};

/// Union-like holder for any component type (used in messages).
pub const MessageComponent = struct {
    type: ComponentType,
    // Other fields vary by type; use std.json.Value for flexible parsing
    custom_id: ?[]const u8 = null,
    components: ?[]std.json.Value = null,
    style: ?u8 = null,
    label: ?[]const u8 = null,
    emoji: ?Emoji = null,
    url: ?[]const u8 = null,
    disabled: ?bool = null,
    options: ?[]SelectOption = null,
    placeholder: ?[]const u8 = null,
    min_values: ?u32 = null,
    max_values: ?u32 = null,
    value: ?[]const u8 = null,
    required: ?bool = null,
    min_length: ?u32 = null,
    max_length: ?u32 = null,
    channel_types: ?[]ChannelType = null,
};
