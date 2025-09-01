module exclusuive::shop;

use std::string::String;
use sui::dynamic_field;
use sui::event::emit;

const ENotAuthorized: u64 = 2;

// =======================================================
// ======================== Structs
// =======================================================

public struct Shop has key, store {
    id: UID,
    name: String,
    description: String,
}

public struct ShopCap has key, store {
    id: UID,
    shop_id: ID,
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

public struct ShopCreated has copy, drop {
    id: ID,
    name: String,
    description: String,
}

public struct ShopUpdated has copy, drop {
    id: ID,
    name: String,
    description: String,
}

// =======================================================
// ======================== Public Functions
// =======================================================

public fun new_shop(
    name: String,
    description: String,
    ctx: &mut TxContext,
): (Shop, ShopCap) {
    let shop = Shop {
        id: object::new(ctx),
        name,
        description,
    };

    let shop_cap = ShopCap {
        id: object::new(ctx),
        shop_id: object::id(&shop),
    };

    emit(ShopCreated {
        id: object::id(&shop),
        name,
        description,
    });

    (shop, shop_cap)
}

public fun update_shop(
    shop: &mut Shop,
    shop_cap: &mut ShopCap,
    name: String,
    description: String,
) {
    require_shop_cap(shop, shop_cap);
    shop.name = name;
    shop.description = description;

    emit(ShopUpdated {
        id: object::id(shop),
        name,
        description,
    });
}

public fun add_config(
    shop: &mut Shop,
    shop_cap: &mut ShopCap,
    type_name: String,
    content: String,
) {
    require_shop_cap(shop, shop_cap);

    dynamic_field::add(
        &mut shop.id,
        TypeKey<ConfigType> { type_name },
        ConfigType { content },
    );
}

public fun require_shop_cap(shop: &Shop, shop_cap: &ShopCap) {
    assert!(shop_cap.shop_id == object::id(shop), ENotAuthorized);
}

// =======================================================
// ======================== Entry Functions
// =======================================================

entry fun create_shop(name: String, description: String, ctx: &mut TxContext) {
    let (shop, shop_cap) = new_shop(name, description, ctx);
    transfer::share_object(shop);
    transfer::transfer(shop_cap, ctx.sender());
}

// =======================================================
// ======================== internal Functions
// =======================================================

public(package) fun get_uid(shop: &Shop): &UID {
    &shop.id
}

public(package) fun get_mut_uid(shop: &mut Shop): &mut UID {
    &mut shop.id
}

public fun get_shop_id_from_cap(shop_cap: &ShopCap): &ID {
    &shop_cap.shop_id
}

public fun get_shop_name(shop: &Shop): &String {
    &shop.name
}

public fun get_shop_description(shop: &Shop): &String {
    &shop.description
}

public fun check_config(shop: &Shop, type_name: String): bool {
    dynamic_field::exists_(
        &shop.id,
        TypeKey<ConfigType> { type_name },
    )
}

public fun get_config(shop: &Shop, type_name: String): &ConfigType {
    dynamic_field::borrow(
        &shop.id,
        TypeKey<ConfigType> { type_name },
    )
}

public fun get_config_content(config_type: &ConfigType): &String {
    &config_type.content
}

