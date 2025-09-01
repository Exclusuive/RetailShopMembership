module exclusuive::retail_market;

use std::string::String;

use sui::balance::{Self, Balance};
use sui::vec_set::VecSet;
use sui::vec_map::VecMap;

use usdc::usdc::USDC;

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
  // membership: Membership
}

public struct MembershipPointPolicyKey has store, copy, drop {}
public struct StampPolicyKey has store, copy, drop {}

public struct PurchaseRequest {
  price: u64,
  paid: u64,
  paid_by_points: u64
}

entry fun create_market() {}

public fun new_market() {}
