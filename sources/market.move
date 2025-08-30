module exclusuive::market;

use exclusuive::community::{Community, CommunityCap, get_uid as get_uid_community, get_mut_uid as get_mut_uid_community, require_community_cap};
use std::string::String;
use sui::dynamic_object_field;
use sui::vec_map::{Self, VecMap};
use sui::coin::{Self, Coin};
use sui::balance::{Self, Balance};
use sui::sui::SUI;


const EAlreadyExists: u64 = 3;
const ENotExists: u64 = 4;
const EInsufficientAmount: u64 = 5;


public struct Market has key, store {
    id: UID,
    community_id: ID,
    sui_balance : Balance<SUI>,

}

public struct Product has key, store {
    id: UID,
    community_id: ID,
    market_id: ID,
    category: String,
    name: String,
    description: String,
    image_url: String,
    price: u64,
    options: VecMap<u64, ProductOption>,
    option_index: u64,
}

public struct ProductOption has store, drop, copy { 
    category : String,
    name : String,
    price : u64,
}

public struct ProductKey has copy, drop, store {
    product_id: ID
}


public fun new_market(community: &mut Community, community_cap: &mut CommunityCap, ctx: &mut TxContext) {
    require_community_cap(community, community_cap);
    assert!(check_market(community), EAlreadyExists);

    let id = object::new(ctx);
    let community_id = object::id(community);

    dynamic_object_field::add(
        get_mut_uid_community(community),
        b"market",
        Market {
            id,
            community_id,
            sui_balance: balance::zero<SUI>(),
        },
    );
}


public fun add_product(community: &mut Community, community_cap: &mut CommunityCap, market: &mut Market, category: String, name: String, description: String, image_url: String, price: u64, ctx: &mut TxContext) {
    require_community_cap(community, community_cap);
    assert!(check_market(community), ENotExists);

    let id = object::new(ctx);
    let community_id = object::id(community);
    let market_id = object::id(market);

    let product = Product {
        id,
        community_id,
        market_id,
        category,
        name,
        description,
        image_url,
        price,
        options: vec_map::empty<u64, ProductOption>(),
        option_index: 0,
    };

    dynamic_object_field::add(
        &mut market.id,
        ProductKey{ product_id: object::id(&product) },
        product,
    );
}

public fun edit_product(community: &mut Community, community_cap: &mut CommunityCap, product: &Product, category: String, name: String, description: String, image_url: String, price: u64) {
    require_community_cap(community, community_cap);
    assert!(check_market(community), ENotExists);
    assert!(check_product(community, product), ENotExists);
    let market = borrow_mut_market(community);
    let product: &mut Product = dynamic_object_field::borrow_mut(
        &mut market.id,
        ProductKey { product_id: object::id(product) },
    );
    product.category = category;
    product.name = name;
    product.description = description;
    product.image_url = image_url;
    product.price = price;

}

public fun delete_product(community: &mut Community, community_cap: &mut CommunityCap, product: &mut Product) {
    require_community_cap(community, community_cap);
    assert!(check_market(community), ENotExists);
    assert!(check_product(community, product), ENotExists);
    let market = borrow_mut_market(community);
    let product: Product = dynamic_object_field::remove(
        &mut market.id,
        ProductKey { product_id: object::id(product) },
    );
    let Product { id, ..} = product;
    object::delete(id);
}

public fun add_product_option(community: &mut Community, community_cap: &mut CommunityCap, product: &mut Product, category: String, name: String, price: u64) {
    require_community_cap(community, community_cap);
    assert!(check_market(community), ENotExists);
    assert!(check_product(community, product), ENotExists);
    let market = borrow_mut_market(community);
    let product: &mut Product = dynamic_object_field::borrow_mut(
        &mut market.id,
        ProductKey { product_id: object::id(product) },
    );
    let option = ProductOption { category, name, price };
    vec_map::insert(&mut product.options, product.option_index, option);
    product.option_index = product.option_index + 1;
}

public fun remove_product_option(community: &mut Community, community_cap: &mut CommunityCap, product: &mut Product, index: u64) {
    require_community_cap(community, community_cap);
    assert!(check_market(community), ENotExists);
    assert!(check_product(community, product), ENotExists);
    let market = borrow_mut_market(community);
    let product: &mut Product = dynamic_object_field::borrow_mut(
        &mut market.id,
        ProductKey { product_id: object::id(product) },
    );
    vec_map::remove(&mut product.options, &index);
}

public fun get_selected_options(product: &Product, options: &vector<u64>): vector<ProductOption> {
    let mut selected_options = vector::empty<ProductOption>();
    let mut i = 0;
    while (i < vector::length(options)) {
        let option_id = *vector::borrow(options, i);
        let option = vec_map::get(&product.options, &option_id);
        vector::push_back(&mut selected_options, *option);
        i = i + 1;
    };
    selected_options
}


public fun calculate_product_price_without_membership(product: &Product, options: &vector<ProductOption>): u64 {
    let mut price = product.price;
    let n = vector::length(options);
    let mut i = 0;
    while (i < n) {
        let option = &options[i];
        price = price + option.price;
        i = i + 1;
    };
    price
}

public fun purchase_product_without_membership(
    market: &mut Market,
    price : u64,
    coin: Coin<SUI>,
) {
    assert!(coin::value(&coin) >= price, EInsufficientAmount);
    let paid_balance = coin::into_balance(coin);
    balance::join(&mut market.sui_balance, paid_balance);
}


// TODO : Membership Purchase, Calculate with Membership 함수 만들기
// TODO : 더 다양한 코인을 받을 수 있게 하기



public fun borrow_mut_market(community: &mut Community): &mut Market {
    dynamic_object_field::borrow_mut(
        get_mut_uid_community(community),
        b"market",
    )
}


public fun check_product(community: &mut Community,  product: & Product): bool {
    let market = borrow_mut_market(community);      
    dynamic_object_field::exists_(
        & market.id,
        ProductKey { product_id: object::id(product) },
    )
}

public fun check_market(community: &Community): bool {
    dynamic_object_field::exists_(
        get_uid_community(community),
        b"market",
    )
}


public(package) fun get_uid(market: &Market): &UID {
    &market.id
}

public(package) fun get_mut_uid(market: &mut Market): &mut UID {
    &mut market.id
}

// === add to exclusuive::market (inside the same module) ===

#[test_only]
public fun add_product_for_test(
    community: &mut Community,
    community_cap: &mut CommunityCap,
    category: String, name: String, description: String, image_url: String, price: u64,
    ctx: &mut TxContext
): ID {
    require_community_cap(community, community_cap);
    // 마켓이 있어야만 추가 가능
    assert!(check_market(community), ENotExists);
    let community_id = object::id(community);
    let market = borrow_mut_market(community);

    let id = object::new(ctx);
    let market_id = object::id(market);

    let product = Product {
        id,
        community_id,
        market_id,
        category,
        name,
        description,
        image_url,
        price,
        options: vec_map::empty<u64, ProductOption>(),
        option_index: 0,
    };
    let product_id = object::id(&product);

    dynamic_object_field::add(
        &mut market.id,
        ProductKey{ product_id: product_id },
        product,
    );
    product_id
}

#[test_only]
public fun borrow_mut_product_by_id_for_test(
    community: &mut Community,
    product_id: ID
): &mut Product {
    let market = borrow_mut_market(community);
    dynamic_object_field::borrow_mut(
        &mut market.id,
        ProductKey { product_id }
    )
}
