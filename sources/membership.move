module exclusuive::membership;

use exclusuive::shop::{Shop, ShopCap};
use std::string::String;
use sui::display;
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

public struct MEMBERSHIP has drop {}


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

fun init(otw: MEMBERSHIP, ctx: &mut TxContext) {
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

// =======================================================
// ======================== Public Functions 
// =======================================================

public fun new_membership_type(
    shop: &mut Shop,
    shop_cap: &mut ShopCap,
    name: String,
    image_url: String,
    allow_user_mint: bool,
    period: Option<u64>,
) {
    shop.check_cap(shop_cap);
    assert!(!exists_membership_type(shop, name), EAlreadyExists);

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

    shop.df_add(MembershipTypeKey<MembershipType> { shop_id, name }, membership_type);
}

public fun update_membership_type(
    shop: &mut Shop,
    shop_cap: &mut ShopCap,
    name: String,
    image_url: String,
    allow_user_mint: bool,
    period: Option<u64>,
) {
    shop.check_cap(shop_cap);
    assert!(exists_membership_type(shop, name), ENotExists);

    let shop_id = object::id(shop);

    let membership_type: &mut MembershipType = shop.df_borrow_mut(MembershipTypeKey<MembershipType> { shop_id, name });

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
    shop.check_cap(shop_cap);
    assert!(exists_membership_type(shop, name), ENotExists);

    let shop_id = object::id(shop);
    let membership_type: &MembershipType = shop.df_borrow(MembershipTypeKey<MembershipType> { shop_id, name });

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
    assert!(exists_membership_type(shop, membership.name), ENotExists);
    let shop_id = object::id(shop);
    let membership_type: &MembershipType = shop.df_borrow(MembershipTypeKey<MembershipType> { shop_id, name: membership.name });

    membership.image_url = membership_type.image_url;
    membership.version = membership_type.version;
}

public fun exists_membership_type(shop: &mut Shop, name: String): bool {
    let shop_id = object::id(shop);
    shop.df_exists(MembershipTypeKey<MembershipType> { shop_id, name })
}

// =======================================================
// ======================== Package Functions 
// =======================================================

public (package) fun new_membership_type_key(shop: &Shop, name: String): MembershipTypeKey<MembershipType> {
    MembershipTypeKey<MembershipType> {shop_id: object::id(shop), name}
}

public (package) fun name(membership: &Membership): String {
    membership.name
}

public (package) fun image_url(membership: &Membership): String {
    membership.image_url
}

public (package) fun mt_image_url(shop: &Shop, name: String): String {
    let membership_type: &MembershipType = shop.df_borrow(MembershipTypeKey<MembershipType> { shop_id: object::id(shop), name });
    membership_type.image_url
}

public (package) fun mt_allow_user_mint(shop: &Shop, name: String): bool {
    let membership_type: &MembershipType = shop.df_borrow(MembershipTypeKey<MembershipType> { shop_id: object::id(shop), name });
    membership_type.allow_user_mint
}

public (package) fun mt_period(shop: &Shop, name: String): Option<u64> {
    let membership_type: &MembershipType = shop.df_borrow(MembershipTypeKey<MembershipType> { shop_id: object::id(shop), name });
    membership_type.period
}

public (package) fun withdraw_membership_points(membership: &mut Membership, amount: u64) {
    membership.points = membership.points - amount;
}