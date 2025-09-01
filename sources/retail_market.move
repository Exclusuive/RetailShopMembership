module exclusuive::retail_market;

use std::string::String;

use sui::balance::{Self, Balance};
use sui::vec_set::{Self,VecSet};
use sui::vec_map::{Self, VecMap};
use sui::object::{Self};

use usdc::usdc::USDC;

use exclusuive::exclusuive_membership::MembershipType;
use exclusuive::shop::{Self, Shop, ShopCap};

const ENotAuthorized: u64 = 2;

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

entry fun create_market(shop: &Shop, cap: &ShopCap, ctx: &mut TxContext) {
  let market = new_market(shop, cap, ctx);
  transfer::share_object(market);
}

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
