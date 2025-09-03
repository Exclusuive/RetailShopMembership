module exclusuive::exclusuive_membership;

use exclusuive::shop::{Shop, ShopCap, get_uid as get_uid_shop, get_mut_uid as get_mut_uid_shop, require_shop_cap};
use std::string::String;
use sui::display;
use sui::dynamic_field;
use sui::event::emit;
use sui::package;

const EAlreadyExists: u64 = 3;
const ENotExists: u64 = 4;

const MAX_EXPIRY_DATE: u64 = 18446744073709551615;

// =======================================================
// ======================== Structs
// =======================================================

public struct MembershipType has copy, drop, store {
    shop_id: ID,
    name: String,
    image_url: String,
    allow_user_mint: bool,
    period: Option<u64>,
    version: u64,
}

public struct Membership has key, store {
    id: UID,
    shop_id: ID,
    name: String,
    image_url: String,
    expiry_date: u64,
    version: u64,
    points: u64
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
    shop_id: ID,
    name: String,
    image_url: String,
    allow_user_mint: bool,
    period: Option<u64>,
    version: u64,
}

public struct MembershipTypeUpdated has copy, drop {
    shop_id: ID,
    name: String,
    image_url: String,
    allow_user_mint: bool,
    period: Option<u64>,
    version: u64,
}

public struct MembershipCreated has copy, drop {
    shop_id: ID,
    membership_id: ID,
    name: String,
    image_url: String,
    expiry_date: u64,
    version: u64,
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
    period: Option<u64>,
) {
    require_shop_cap(shop, shop_cap);
    assert!(!check_membership_type(shop, name), EAlreadyExists);

    let shop_id = object::id(shop);
    
    let membership_type = MembershipType {
        shop_id,
        name,
        image_url,
        allow_user_mint,
        period,
        version: 0,
    };

    emit(MembershipTypeCreated {
        shop_id,
        name,
        image_url,
        allow_user_mint,
        period,
        version: membership_type.version,
    });

    dynamic_field::add(
        get_mut_uid_shop(shop),
        MembershipTypeKey<MembershipType> { shop_id, name },
        membership_type,
    );
}

public fun update_membership_type(
    shop: &mut Shop,
    shop_cap: &mut ShopCap,
    name: String,
    image_url: String,
    allow_user_mint: bool,
    period: Option<u64>,
) {
    require_shop_cap(shop, shop_cap);
    assert!(check_membership_type(shop, name), ENotExists);

    let shop_id = object::id(shop);

    let membership_type: &mut MembershipType = dynamic_field::borrow_mut(
        get_mut_uid_shop(shop),
        MembershipTypeKey<MembershipType> { shop_id, name },
    );

    membership_type.image_url = image_url;
    membership_type.allow_user_mint = allow_user_mint;
    membership_type.period = period;
    membership_type.version = membership_type.version + 1;

    emit(MembershipTypeUpdated {
        shop_id,
        name,
        image_url,
        allow_user_mint,
        period,
        version: membership_type.version,
    });
}

public fun new_membership(
    shop: &mut Shop,
    shop_cap: &mut ShopCap,
    name: String,
    ctx: &mut TxContext,
): Membership {
    require_shop_cap(shop, shop_cap);
    assert!(check_membership_type(shop, name), ENotExists);

    let shop_id = object::id(shop);
    let membership_type: &MembershipType = dynamic_field::borrow(
        get_uid_shop(shop),
        MembershipTypeKey<MembershipType> { shop_id, name },
    );
    let membership = Membership {
        id: object::new(ctx),
        shop_id,
        name,
        image_url: membership_type.image_url,
        expiry_date: ctx.epoch_timestamp_ms() + option::get_with_default(&membership_type.period, MAX_EXPIRY_DATE),
        version: membership_type.version,
        points: 0
    };

    emit(MembershipCreated {
        shop_id,
        membership_id: object::id(&membership),
        name,
        image_url: membership_type.image_url,
        expiry_date: membership.expiry_date,
        version: membership_type.version,
    });

    membership
}

public fun update_membership(
    shop: &mut Shop,
    membership: &mut Membership,
) {
    assert!(check_membership_type(shop, membership.name), ENotExists);
    let shop_id = object::id(shop);
    let membership_type: &MembershipType = dynamic_field::borrow(
        get_uid_shop(shop),
        MembershipTypeKey<MembershipType> { shop_id, name: membership.name },
    );
    membership.image_url = membership_type.image_url;
    membership.version = membership_type.version;
}

public fun check_membership_type(shop: &mut Shop, name: String): bool {
    let shop_id = object::id(shop);
    dynamic_field::exists_(
        get_uid_shop(shop),
        MembershipTypeKey<MembershipType> { shop_id, name },
    )
}


public fun get_membership_type(
    shop: &Shop,
    name: String,
): &MembershipType {
    dynamic_field::borrow(
        get_uid_shop(shop),
        MembershipTypeKey<MembershipType> { shop_id: object::id(shop), name },
    )
}

public fun get_membership_name(membership: &Membership): &String {
    &membership.name
}

public fun get_membership_image_url(membership: &Membership): &String {
    &membership.image_url
}

public fun get_membership_type_image_url(shop: &mut Shop, name: String): &String {
    &get_membership_type(shop, name).image_url
}

public fun get_membership_type_allow_user_mint(shop: &mut Shop, name: String): &bool {
    &get_membership_type(shop, name).allow_user_mint
}

public fun get_membership_type_valid_period(shop: &mut Shop, name: String): &Option<u64> {
    &get_membership_type(shop, name).period
}

// =======================================================
// ======================== internal Functions
// =======================================================

public (package) fun withdraw_membership_points(membership: &mut Membership, amount: u64) {
    membership.points = membership.points - amount;
}