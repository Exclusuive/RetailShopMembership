module exclusuive::community;

use std::string::String;
use sui::dynamic_field;
use sui::event::emit;

const ENotAuthorized: u64 = 2;

// =======================================================
// ======================== Structs
// =======================================================

public struct Community has key, store {
    id: UID,
    name: String,
    description: String,
}

public struct CommunityCap has key, store {
    id: UID,
    community_id: ID,
}

public struct TypeKey<phantom T> has copy, drop, store {
    type_name: String,
}

public struct ConfigType has copy, drop, store {
    content: String,
}

// =======================================================
// ======================== Events
// =======================================================

public struct CommunityCreated has copy, drop {
    id: ID,
    name: String,
    description: String,
}

// =======================================================
// ======================== Public Functions
// =======================================================

public fun new_community(
    name: String,
    description: String,
    ctx: &mut TxContext,
): (Community, CommunityCap) {
    let community = Community {
        id: object::new(ctx),
        name,
        description,
    };

    let com_cap = CommunityCap {
        id: object::new(ctx),
        community_id: object::id(&community),
    };

    emit(CommunityCreated {
        id: object::id(&community),
        name,
        description,
    });

    (community, com_cap)
}

public fun add_config(
    community: &mut Community,
    community_cap: &mut CommunityCap,
    type_name: String,
    content: String,
) {
    require_community_cap(community_cap, community);

    dynamic_field::add(
        &mut community.id,
        TypeKey<ConfigType> { type_name },
        ConfigType { content },
    );
}

public fun require_community_cap(community_cap: &mut CommunityCap, community: &mut Community) {
    assert!(community_cap.community_id == object::id(community), ENotAuthorized);
}

// =======================================================
// ======================== Entry Functions
// =======================================================

entry fun create_community(name: String, description: String, ctx: &mut TxContext) {
    let (com, com_cap) = new_community(name, description, ctx);
    transfer::share_object(com);
    transfer::transfer(com_cap, ctx.sender());
}

// =======================================================
// ======================== internal Functions
// =======================================================

public(package) fun get_uid(community: &Community): &UID {
    &community.id
}

public(package) fun get_mut_uid(community: &mut Community): &mut UID {
    &mut community.id
}
