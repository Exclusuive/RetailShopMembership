module exclusuive::exclusuive_membership;

use exclusuive::shop::{Shop, ShopCap, get_uid, get_mut_uid, require_shop_cap};
use std::string::String;
use sui::display;
use sui::dynamic_field;
use sui::event::emit;
use sui::package;

const EAlreadyExists: u64 = 3;
const ENotExists: u64 = 4;

// =======================================================
// ======================== Structs
// =======================================================

public struct MembershipType has copy, drop, store {
    shop_id: ID,
    name: String,
    image_url: String,
    allow_user_mint: bool,
    valid_period: Option<u64>,
    version: u64,
}

public struct Membership has key, store {
    id: UID,
    shop_id: ID,
    name: String,
    image_url: String,
    expiry_date: u64,
    version: u64,
}

public struct MembershipTypeKey<phantom T> has copy, drop, store {
    shop_id: ID,
    name: String,
}

public struct EXCLUSUIVE_MEMBERSHIP has drop {}

// =======================================================
// ======================== Events
// =======================================================
public struct MembershipTypeCreated has copy, drop {
    community_id: ID,
    name: String,
    image_url: String,
    allow_user_mint: bool,
    valid_period: Option<u64>,
    version: u64,
}

public struct MembershipTypeUpdated has copy, drop {
    community_id: ID,
    name: String,
    image_url: String,
    allow_user_mint: bool,
    valid_period: Option<u64>,
    version: u64,
}

public struct MembershipCreated has copy, drop {
    community_id: ID,
    membership_id: ID,
    name: String,
}

fun init(otw: EXCLUSUIVE_MEMBERSHIP, ctx: &mut TxContext) {
    let keys = vector[b"name".to_string(), b"image_url".to_string()];

    let values = vector[b"{name}".to_string(), b"{image_url}".to_string()];

    // Claim the `Publisher` for the package!
    let publisher = package::claim(otw, ctx);

    let mut display = display::new_with_fields<Membership>(
        &publisher,
        keys,
        values,
        ctx,
    );

    // Commit first version of `Display` to apply changes.
    display.update_version();
    transfer::public_transfer(publisher, ctx.sender());
    transfer::public_transfer(display, ctx.sender());
}

public fun new_membership_type(
    shop: &mut Shop,
    shop_cap: &mut ShopCap,
    name: String,
    image_url: String,
    allow_user_mint: bool,
    valid_period: Option<u64>,
) {
    require_shop_cap(shop, shop_cap);
    assert!(!check_membership_type(shop, name), EAlreadyExists);

    let shop_id = object::id(shop);

    let membership_type_key = make_membership_type_key(community, name);

    let membership_type = MembershipType {
        community_id,
        name,
        image_url,
        allow_user_mint,
        valid_period,
        version: 0,
    };

    emit(MembershipTypeCreated {
        community_id,
        name,
        image_url,
        allow_user_mint,
        valid_period,
        version: membership_type.version,
    });

    dynamic_field::add(
        get_mut_uid(community),
        membership_type_key,
        membership_type,
    );
}

public fun update_membership_type(
    community: &mut Community,
    community_cap: &mut CommunityCap,
    name: String,
    image_url: String,
    allow_user_mint: bool,
    valid_period: Option<u64>,
) {
    require_community_cap(community, community_cap);
    assert!(check_membership_type(community, name), ENotExists);

    let community_id = object::id(community);
    let membership_type_key = make_membership_type_key(community, name);

    let membership_type: &mut MembershipType = dynamic_field::borrow_mut(
        get_mut_uid(community),
        membership_type_key,
    );

    membership_type.image_url = image_url;
    membership_type.allow_user_mint = allow_user_mint;
    membership_type.valid_period = valid_period;
    membership_type.version = membership_type.version + 1;

    emit(MembershipTypeUpdated {
        community_id,
        name,
        image_url,
        allow_user_mint,
        valid_period,
        version: membership_type.version,
    });
}

public fun new_membership(
    community: &mut Community,
    community_cap: &mut CommunityCap,
    name: String,
    ctx: &mut TxContext,
): Membership {
    require_community_cap(community, community_cap);
    assert!(check_membership_type(community, name), ENotExists);

    let community_id = object::id(community);
    let membership_type: &MembershipType = dynamic_field::borrow(
        get_uid(community),
        MembershipTypeKey<MembershipType> { community_id, name },
    );
    let membership = Membership {
        id: object::new(ctx),
        community_id,
        name,
        image_url: membership_type.image_url,
        allow_user_mint: membership_type.allow_user_mint,
        valid_period: membership_type.valid_period,
        updated_at: ctx.epoch_timestamp_ms(),
        version: membership_type.version,
    };

    emit(MembershipCreated {
        community_id,
        membership_id: object::id(&membership),
        name,
    });

    membership
}

public fun update_membership(
    community: &mut Community,
    membership: &mut Membership,
    ctx: &mut TxContext,
) {
    assert!(check_membership_type(community, membership.name), ENotExists);
    let community_id = object::id(community);
    let membership_type: &MembershipType = dynamic_field::borrow(
        get_uid(community),
        MembershipTypeKey<MembershipType> { community_id, name: membership.name },
    );
    membership.image_url = membership_type.image_url;
    membership.allow_user_mint = membership_type.allow_user_mint;
    membership.valid_period = membership_type.valid_period;
    membership.version = membership_type.version;
    membership.updated_at = ctx.epoch_timestamp_ms();
}

public fun check_membership_type(community: &mut Community, name: String): bool {
    let community_id = object::id(community);
    dynamic_field::exists_(
        get_uid(community),
        MembershipTypeKey<MembershipType> { community_id, name },
    )
}

public fun make_membership_type_key(
    community: &mut Community,
    name: String,
): MembershipTypeKey<MembershipType> {
    let community_id = object::id(community);
    MembershipTypeKey<MembershipType> { community_id, name }
}

public fun get_membership_type(
    community: &mut Community,
    name: String,
): &MembershipType {
    dynamic_field::borrow(
        get_uid(community),
        MembershipTypeKey<MembershipType> { community_id: object::id(community), name },
    )
}

public fun get_membership_name(membership: &Membership): &String {
    &membership.name
}

public fun get_membership_image_url(membership: &Membership): &String {
    &membership.image_url
}

public fun get_membership_allow_user_mint(membership: &Membership): &bool {
    &membership.allow_user_mint
}

public fun get_membership_valid_period(membership: &Membership): &Option<u64> {
    &membership.valid_period
}
    

public fun get_membership_type_image_url(community: &mut Community, name: String): &String {
    &get_membership_type(community, name).image_url
}

public fun get_membership_type_allow_user_mint(community: &mut Community, name: String): &bool {
    &get_membership_type(community, name).allow_user_mint
}

public fun get_membership_type_valid_period(community: &mut Community, name: String): &Option<u64> {
    &get_membership_type(community, name).valid_period
}
