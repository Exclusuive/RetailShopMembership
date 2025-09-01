module exclusuive::retail_market;

use std::string::String;

use sui::balance::{Self, Balance};
use sui::vec_set::{Self,VecSet};
use sui::vec_map::{Self, VecMap};
use sui::object::{Self};

use usdc::usdc::USDC;

use exclusuive::exclusuive_membership::MembershipType;
use exclusuive::shop::{Self, Shop, ShopCap};

public struct RetailMarket has key, store {
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

entry fun create_market() {}

public fun new_market(shop: &Shop, shop_cap: &ShopCap, ctx: &mut TxContext): RetailMarket  {
  shop::require_shop_cap(shop, shop_cap);

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
