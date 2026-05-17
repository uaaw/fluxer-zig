const std = @import("std");

/// Bitfield wrapper for Discord Gateway intents.
pub const Intents = struct {
    value: u64,

    pub fn init() Intents {
        return .{ .value = 0 };
    }

    pub fn guilds() Intents {
        return .{ .value = 1 << 0 };
    }

    pub fn guildMembers() Intents {
        return .{ .value = 1 << 1 };
    }

    pub fn guildBans() Intents {
        return .{ .value = 1 << 2 };
    }

    pub fn guildEmojis() Intents {
        return .{ .value = 1 << 3 };
    }

    pub fn guildIntegrations() Intents {
        return .{ .value = 1 << 4 };
    }

    pub fn guildWebhooks() Intents {
        return .{ .value = 1 << 5 };
    }

    pub fn guildInvites() Intents {
        return .{ .value = 1 << 6 };
    }

    pub fn guildVoiceStates() Intents {
        return .{ .value = 1 << 7 };
    }

    pub fn guildPresences() Intents {
        return .{ .value = 1 << 8 };
    }

    pub fn guildMessages() Intents {
        return .{ .value = 1 << 9 };
    }

    pub fn guildMessageReactions() Intents {
        return .{ .value = 1 << 10 };
    }

    pub fn guildMessageTyping() Intents {
        return .{ .value = 1 << 11 };
    }

    pub fn directMessages() Intents {
        return .{ .value = 1 << 12 };
    }

    pub fn directMessageReactions() Intents {
        return .{ .value = 1 << 13 };
    }

    pub fn directMessageTyping() Intents {
        return .{ .value = 1 << 14 };
    }

    pub fn messageContent() Intents {
        return .{ .value = 1 << 15 };
    }

    pub fn guildScheduledEvents() Intents {
        return .{ .value = 1 << 16 };
    }

    pub fn autoModerationConfiguration() Intents {
        return .{ .value = 1 << 20 };
    }

    pub fn autoModerationExecution() Intents {
        return .{ .value = 1 << 21 };
    }

    pub fn combine(self: Intents, other: Intents) Intents {
        return .{ .value = self.value | other.value };
    }

    pub fn has(self: Intents, other: Intents) bool {
        return (self.value & other.value) == other.value;
    }
};

test "Intents init is zero" {
    const intents = Intents.init();
    try std.testing.expectEqual(@as(u64, 0), intents.value);
}

test "Intents guilds bit" {
    const intents = Intents.guilds();
    try std.testing.expectEqual(@as(u64, 1 << 0), intents.value);
}

test "Intents combine" {
    const a = Intents.guilds();
    const b = Intents.guildMessages();
    const combined = a.combine(b);
    try std.testing.expectEqual(@as(u64, (1 << 0) | (1 << 9)), combined.value);
}

test "Intents has" {
    const combined = Intents.guilds().combine(Intents.guildMessages());
    try std.testing.expect(combined.has(Intents.guilds()));
    try std.testing.expect(combined.has(Intents.guildMessages()));
    try std.testing.expect(!combined.has(Intents.guildMembers()));
}

test "Intents all bits unique" {
    // 各intentのビット値が重複していないことを確認
    const all = [_]Intents{
        Intents.guilds(),
        Intents.guildMembers(),
        Intents.guildBans(),
        Intents.guildEmojis(),
        Intents.guildIntegrations(),
        Intents.guildWebhooks(),
        Intents.guildInvites(),
        Intents.guildVoiceStates(),
        Intents.guildPresences(),
        Intents.guildMessages(),
        Intents.guildMessageReactions(),
        Intents.guildMessageTyping(),
        Intents.directMessages(),
        Intents.directMessageReactions(),
        Intents.directMessageTyping(),
        Intents.messageContent(),
        Intents.guildScheduledEvents(),
        Intents.autoModerationConfiguration(),
        Intents.autoModerationExecution(),
    };
    var mask: u64 = 0;
    for (all) |intent| {
        try std.testing.expect(mask & intent.value == 0);
        mask |= intent.value;
    }
}