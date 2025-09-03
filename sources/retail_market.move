module exclusuive::retail_market;

use std::string::String;

use sui::balance::{Self, Balance};
use sui::vec_set::{Self,VecSet};
use sui::vec_map::{Self, VecMap};
use sui::dynamic_field::{Self as df};

use usdc::usdc::USDC;

use exclusuive::exclusuive_membership::MembershipType;
use exclusuive::shop::{Self, Shop, ShopCap};

const ENotAuthorized: u64 = 2;
const ENotEqualCategoryName: u64 = 3;

// =======================================================
// ======================== Structs
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

public struct Product has copy, store {
  shop_id: ID,
  category_name: String,
  option_indexes: vector<u64>,
  name: String,
  description: String,
  image_url: String,
  price: u64

}
public struct Reciept has key, store {
  id: UID,
  shop_id: ID,
  products: vector<Product>,
  membership_type: MembershipType
}

public struct MembershipPointPolicyKey has store, copy, drop {}
public struct StampPolicyKey has store, copy, drop {}

public struct PurchaseRequest {
  price: u64,
  paid: u64,
  paid_by_points: u64
}

// =======================================================
// ======================== Entry Functions
// =======================================================

entry fun create_market(shop: &Shop, cap: &ShopCap, ctx: &mut TxContext) {
  let market = new_market(shop, cap, ctx);
  transfer::share_object(market);
}

// =======================================================
// ======================== Public Functions
// =======================================================

public fun new_market(shop: &Shop, cap: &ShopCap, ctx: &mut TxContext): RetailMarket  {
  shop::require_shop_cap(shop, cap);

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
  assert!(market.shop_id == cap.get_shop_id_from_cap() , ENotAuthorized);
  market.categories.insert(name);
}

public fun add_custom_option(market: &mut RetailMarket, cap: &ShopCap, category_name: String, name: String, price: u64) {
  assert!(market.shop_id == cap.get_shop_id_from_cap() , ENotAuthorized);
  let current_index = market.option_index;
  market.option_index = current_index + 1;

  let custom_option = CustomOption {
    category_name,
    name,
    price
  };
  market.custom_options.insert(current_index, custom_option);
}

public fun add_product(market: &mut RetailMarket, cap: &ShopCap, category_name: String, name: String, description: String, image_url: String, price: u64) {
  assert!(market.shop_id == cap.get_shop_id_from_cap() , ENotAuthorized);
  let shop_id = cap.get_shop_id_from_cap();

  let product = Product{
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

public fun add_option_to_product(market: &mut RetailMarket, cap: &ShopCap, product_name: String, option_index: u64) {
  assert!(market.shop_id == cap.get_shop_id_from_cap() , ENotAuthorized);

  let product = df::borrow_mut<String, Product>(&mut market.id, product_name);
  let custom_option = market.custom_options.get(&option_index);

  assert!(product.category_name == custom_option.category_name);
  product.option_indexes.push_back(option_index);
}

public fun purchase_products(market: &RetailMarket, product_names: vector<String>, option_indexes_vec: vector<vector<u64>>): vector<PurchaseRequest> {
  let mut purchase_request_vec = vector<PurchaseRequest>[];

  product_names.do!(|name| {
    let (_, index) = product_names.index_of(&name);
    let product = df::borrow<String, Product>(&market.id, name);
    let option_indexes = option_indexes_vec.borrow(index);

    let purchase_request = request_purchase(market, product, option_indexes);

    purchase_request_vec.push_back(purchase_request);
  });

  purchase_request_vec
}

// =======================================================
// ======================== internal Functions
// =======================================================


fun request_purchase(market: &RetailMarket, product: &Product, option_indexes: &vector<u64>): PurchaseRequest {
  let mut total_price = product.price;
  option_indexes.do_ref!(|i| {
    let option = market.custom_options.get(i);
    total_price = total_price + option.price;
  });

  PurchaseRequest {
    price: total_price,
    paid: 0,
    paid_by_points: 0
  }
}
