const std = @import("std");
const Snowflake = @import("snowflake.zig").Snowflake;
const User = @import("user.zig").User;
const GuildMember = @import("guild_member.zig").GuildMember;
const Channel = @import("channel.zig").Channel;
const Role = @import("guild.zig").Role;

/// Interaction type sent over the gateway.
pub const InteractionType = enum(u8) {
    Ping = 1,
    ApplicationCommand = 2,
    MessageComponent = 3,
    ApplicationCommandAutocomplete = 4,
    ModalSubmit = 5,
};

/// Type of application command.
pub const ApplicationCommandType = enum(u8) {
    ChatInput = 1,
    User = 2,
    Message = 3,
};

/// Type of application command option.
pub const ApplicationCommandOptionType = enum(u8) {
    SubCommand = 1,
    SubCommandGroup = 2,
    String = 3,
    Integer = 4,
    Boolean = 5,
    User = 6,
    Channel = 7,
    Role = 8,
    Mentionable = 9,
    Number = 10,
    Attachment = 11,
};

/// A choice for an application command option.
pub const ApplicationCommandOptionChoice = struct {
    name: []const u8,
    name_localizations: ?std.json.Value = null,
    value: std.json.Value,
};

/// An option for an application command.
pub const ApplicationCommandOption = struct {
    type: ApplicationCommandOptionType,
    name: []const u8,
    name_localizations: ?std.json.Value = null,
    description: []const u8,
    description_localizations: ?std.json.Value = null,
    required: bool = false,
    choices: ?[]ApplicationCommandOptionChoice = null,
    options: ?[]ApplicationCommandOption = null,
    channel_types: ?[]u8 = null,
    min_value: ?f64 = null,
    max_value: ?f64 = null,
    min_length: ?u32 = null,
    max_length: ?u32 = null,
    autocomplete: bool = false,
};

/// An application command.
pub const ApplicationCommand = struct {
    id: ?Snowflake = null,
    type: ?ApplicationCommandType = null,
    application_id: ?Snowflake = null,
    guild_id: ?Snowflake = null,
    name: []const u8,
    name_localizations: ?std.json.Value = null,
    description: []const u8,
    description_localizations: ?std.json.Value = null,
    options: ?[]ApplicationCommandOption = null,
    default_member_permissions: ?[]const u8 = null,
    dm_permission: ?bool = null,
    nsfw: bool = false,
    version: ?Snowflake = null,
};

/// Resolved data for an interaction.
pub const InteractionDataResolved = struct {
    users: ?std.json.Value = null,
    members: ?std.json.Value = null,
    roles: ?std.json.Value = null,
    channels: ?std.json.Value = null,
    messages: ?std.json.Value = null,
    attachments: ?std.json.Value = null,
};

/// Data attached to an interaction.
pub const InteractionData = struct {
    id: ?Snowflake = null,
    name: ?[]const u8 = null,
    type: ?ApplicationCommandType = null,
    resolved: ?InteractionDataResolved = null,
    options: ?[]ApplicationCommandInteractionDataOption = null,
    guild_id: ?Snowflake = null,
    target_id: ?Snowflake = null,
};

/// An option value from a command interaction.
pub const ApplicationCommandInteractionDataOption = struct {
    name: []const u8,
    type: ApplicationCommandOptionType,
    value: ?std.json.Value = null,
    options: ?[]ApplicationCommandInteractionDataOption = null,
    focused: bool = false,
};

/// An interaction received over the gateway.
pub const Interaction = struct {
    id: Snowflake,
    application_id: Snowflake,
    type: InteractionType,
    data: ?InteractionData = null,
    guild_id: ?Snowflake = null,
    channel_id: ?Snowflake = null,
    member: ?GuildMember = null,
    user: ?User = null,
    token: []const u8,
    version: u32 = 1,
    message: ?std.json.Value = null,
    locale: ?[]const u8 = null,
    guild_locale: ?[]const u8 = null,
    app_permissions: ?[]const u8 = null,
};

/// Callback type for interaction responses.
pub const InteractionCallbackType = enum(u8) {
    Pong = 1,
    ChannelMessageWithSource = 4,
    DeferredChannelMessageWithSource = 5,
    DeferredUpdateMessage = 6,
    UpdateMessage = 7,
    ApplicationCommandAutocompleteResult = 8,
    Modal = 9,
};

/// Data for an interaction callback.
pub const InteractionCallbackData = struct {
    tts: bool = false,
    content: ?[]const u8 = null,
    embeds: ?[]std.json.Value = null,
    allowed_mentions: ?std.json.Value = null,
    flags: ?u64 = null,
    components: ?[]std.json.Value = null,
    custom_id: ?[]const u8 = null,
    title: ?[]const u8 = null,
};

/// Response to an interaction.
pub const InteractionResponse = struct {
    type: InteractionCallbackType,
    data: ?InteractionCallbackData = null,
};
