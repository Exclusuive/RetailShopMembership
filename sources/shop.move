module exclusuive::shop;

use std::string::String;
use sui::event::emit;

use sui::balance::{Self, Balance};
use sui::vec_set::{Self,VecSet};
use sui::vec_map::{Self, VecMap};
use sui::dynamic_field::{Self as df};

use usdc::usdc::USDC;

const ENotAuthorized: u64 = 2;

// =======================================================
// ======================== Structs for Shop
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

public struct ConfigType has copy, drop, store {
    content: String,
}

// =======================================================
// ======================== Structs for RetailMarket
// =======================================================

public struct RetailMarket has key {
  id: UID,
  shop_id: ID,
  balance: Balance<USDC>,
  categories: VecSet<String>,
  custom_options: VecMap<u64, CustomOption>,
  option_index: u64
}

public struct CustomOption has store {
  category_name: String,
  name: String,
  price: u64
}

public struct ProductType has copy, store {
  shop_id: ID,
  category_name: String,
  option_indexes: vector<u64>,
  name: String,
  description: String,
  image_url: String,
  price: u64
}

public struct Product has store {
  shop_id: ID,
  category_name: String,
  option_indexes: vector<u64>,
  name: String,
  description: String,
  image_url: String,
  price: u64

}


public struct PurchaseRequest {
  product: Product,
  price: u64,
  paid: u64,
  paid_by_points: u64
}

// =======================================================
// ======================== Keys
// =======================================================

public struct TypeKey<phantom T> has copy, drop, store {
    type_name: String,
}

public struct MembershipPointPolicyKey has store, copy, drop {}

public struct StampPolicyKey has store, copy, drop {}


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
// ======================== Entry Functions
// =======================================================

entry fun create_shop(name: String, description: String, ctx: &mut TxContext) {
    let (shop, shop_cap) = new_shop(name, description, ctx);
    transfer::share_object(shop);
    transfer::transfer(shop_cap, ctx.sender());
}

entry fun create_market(shop: &Shop, cap: &ShopCap, ctx: &mut TxContext) {
  let market = new_market(shop, cap, ctx);
  transfer::share_object(market);
}

// =======================================================
// ======================== Public Functions for Shop
// =======================================================

public fun new_shop(
    name: String,
    description: String,
    ctx: &mut TxContext,
): (Shop, ShopCap) {
    let shop = Shop { id: object::new(ctx), name, description};

    let shop_cap = ShopCap { id: object::new(ctx), shop_id: object::id(&shop)};

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
    shop.check_cap(shop_cap);
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
    shop.check_cap(shop_cap);

    df::add(
        &mut shop.id,
        TypeKey<ConfigType> { type_name },
        ConfigType { content },
    );
}

// =======================================================
// ======================== Public Functions for RetailMarket
// =======================================================

public fun new_market(shop: &Shop, cap: &ShopCap, ctx: &mut TxContext): RetailMarket  {
    shop.check_cap(cap);

  let shop_id = object::id(shop);
  RetailMarket{
    id: object::new(ctx),
    shop_id,
    balance: balance::zero(),
    categories: vec_set::empty(),
    custom_options: vec_map::empty(),
    option_index: 0
  }
}

public fun add_category(market: &mut RetailMarket, cap: &ShopCap, name: String) {
  assert!(market.shop_id == cap.shop_id , ENotAuthorized);
  market.categories.insert(name);
}

public fun add_custom_option(
    market: &mut RetailMarket, 
    cap: &ShopCap, 
    category_name: String, 
    name: String, 
    price: u64
) {
  assert!(market.shop_id == cap.shop_id , ENotAuthorized);
  let current_index = market.option_index;
  market.option_index = current_index + 1;

  let custom_option = CustomOption { category_name, name, price };
  market.custom_options.insert(current_index, custom_option);
}

public fun add_product_type(
    market: &mut RetailMarket, 
    cap: &ShopCap, 
    category_name: String, 
    name: String, 
    description: String, 
    image_url: String, 
    price: u64
) {
  assert!(market.shop_id == cap.shop_id , ENotAuthorized);
  let shop_id = cap.shop_id;

  let product = ProductType{
    shop_id,
    category_name,
    option_indexes: vector<u64>[],
    name,
    description,
    image_url,
    price
  };

  df::add(&mut market.id, name, product);
}

public fun add_option_to_product_type(market: &mut RetailMarket, cap: &ShopCap, product_name: String, option_index: u64) {
  assert!(market.shop_id == cap.shop_id , ENotAuthorized);

  let product_type = df::borrow_mut<String, ProductType>(&mut market.id, product_name);
  let custom_option = market.custom_options.get(&option_index);

  assert!(product_type.category_name == custom_option.category_name);
  product_type.option_indexes.push_back(option_index);
}

public fun purchase_products(market: &RetailMarket, product_names: vector<String>, option_indexes_vec: vector<vector<u64>>)
: vector<PurchaseRequest> {
  let mut purchase_request_vec = vector<PurchaseRequest>[];

  product_names.do!(|name| {
    let (_, index) = product_names.index_of(&name);
    let product_type = df::borrow<String, ProductType>(&market.id, name);
    let option_indexes = option_indexes_vec.borrow(index);

    let purchase_request = new_request_purchase(market, product_type, option_indexes);

    purchase_request_vec.push_back(purchase_request);
  });

  purchase_request_vec
}

// =======================================================
// ======================== Package Functions
// =======================================================

// =========== Shop
public (package) fun check_cap(shop: &Shop, shop_cap: &ShopCap) {
    assert!(shop_cap.shop_id == object::id(shop), ENotAuthorized);
}

public (package) fun shop_id(shop_cap: &ShopCap): ID {
  shop_cap.shop_id
}

public (package) fun config_type(shop: &Shop, type_name: String): &ConfigType {
    df::borrow(
        &shop.id,
        TypeKey<ConfigType> { type_name },
    )
}

public (package) fun config_content(config_type: &ConfigType): String {
    config_type.content
}


// =========== RetailMarket

public (package) fun add_balance(market: &mut RetailMarket, balance: Balance<USDC>) {
  market.balance.join(balance);
}

public (package) fun new_request_purchase(market: &RetailMarket, product_type: &ProductType, option_indexes: &vector<u64>)
: PurchaseRequest {
  let mut total_price = product_type.price;
  option_indexes.do_ref!(|i| {
    let option = market.custom_options.get(i);
    total_price = total_price + option.price;
  });

  let product = Product {
    shop_id: product_type.shop_id,
    category_name: product_type.category_name,
    option_indexes: vector<u64>[],
    name: product_type.name,
    description: product_type.description,
    image_url: product_type.image_url,
    price: product_type.price
  };

  PurchaseRequest {
    product,
    price: total_price,
    paid: 0,
    paid_by_points: 0
  }
}

// =========== PurchaseRequest

public (package) fun price(request: &PurchaseRequest): u64 {
  request.price
}

public (package) fun paid_by_points(request: &PurchaseRequest): u64 {
  request.paid_by_points
}


public (package) fun add_paid(request: &mut PurchaseRequest, amount: u64) {
  request.paid = request.paid + amount;
}

public (package) fun add_paid_by_points(request: &mut PurchaseRequest, amount: u64) {
  request.paid_by_points = request.paid_by_points + amount;
}

public (package) fun unpack_purchase_request(request: PurchaseRequest)
: (Product, u64, u64, u64) {
  let PurchaseRequest{product, price, paid, paid_by_points} = request;
  (product, price, paid, paid_by_points)
}
