
module exclusuive::membership_policy;

use exclusuive::shop::{Self, Shop, RetailMarket, Product, PurchaseRequest};
use exclusuive::membership::{Self, Membership, MembershipType};

use sui::balance::{Balance};
use usdc::usdc::USDC;

// =======================================================
// ======================== Structs
// =======================================================

public struct Reciept has key, store {
  id: UID,
  shop_id: ID,
  products: vector<Product>,
  membership_type: MembershipType
}

public fun pay(market: &mut RetailMarket, request: &mut PurchaseRequest, payment: &mut Balance<USDC>, amount: u64) {
  let actual_payment = payment.split(amount);
  market.add_balance(actual_payment);
  request.add_paid(amount);
}

public fun pay_with_membership_point(request: &mut PurchaseRequest, membership: &mut Membership, amount: u64) {
  membership.withdraw_membership_points(amount);
  request.add_paid_by_points(amount);
}

public fun new_reciept(shop: &Shop, membership: &Membership, ctx: &mut TxContext): Reciept {
  let membership_type_key = membership::new_membership_type_key(shop, membership.name());
  Reciept {
    id: object::new(ctx),
    shop_id: object::id(shop),
    products: vector<Product>[],
    membership_type: *shop.df_borrow(membership_type_key)
  }
}

public fun confirm_purchase_request(request: PurchaseRequest, reciept: &mut Reciept) {
  let (product, price, paid, paid_by_points) = shop::unpack_purchase_request(request);
  assert!(price == paid + paid_by_points, 10);
  reciept.products.push_back(product)
}
