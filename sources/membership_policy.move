
module exclusuive::membership_policy;

use exclusuive::shop::{Self, Shop, ShopCap, RetailMarket, Product, PurchaseRequest};

use std::string::String;
use sui::balance::{Balance};
use sui::event::emit;
use sui::display;
use sui::package;

use usdc::usdc::USDC;

const ENotExists: u64 = 4;

const MAX_EXPIRY_DATE: u64 = 18446744073709551615;

// =======================================================
// ======================== Structs
// =======================================================
public struct MembershipPolicy has key, store {
    id: UID,
    shop_id: ID,
}

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

public struct Reciept has key, store {
  id: UID,
  shop_id: ID,
  products: vector<Product>,
  membership_type: MembershipType
}

public struct MEMBERSHIP_POLICY has drop {}

public struct MembershipTypeKey<phantom T> has copy, drop, store {
    shop_id: ID,
    name: String,
}
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


fun init(otw: MEMBERSHIP_POLICY, ctx: &mut TxContext) {
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

// =============== Membership Type
public fun new_membership_type(
    shop: &mut Shop,
    shop_cap: &mut ShopCap,
    name: String,
    image_url: String,
    allow_user_mint: bool,
    period: Option<u64>,
) {
    shop.check_cap(shop_cap);

    let shop_id = object::id(shop);
    assert!(shop.df_exists(MembershipTypeKey<MembershipType> { shop_id, name: name }), ENotExists);
    
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

    let shop_id = object::id(shop);
    assert!(shop.df_exists(MembershipTypeKey<MembershipType> { shop_id, name: name }), ENotExists);

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

// =============== Membership 
public fun new_membership(
    shop: &Shop,
    shop_cap: &mut ShopCap,
    name: String,
    ctx: &mut TxContext,
): Membership {
    shop.check_cap(shop_cap);

    let shop_id = object::id(shop);
    assert!(shop.df_exists(MembershipTypeKey<MembershipType> { shop_id, name: name }), ENotExists);

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
    shop: &Shop,
    membership: &mut Membership,
) {
    let shop_id = object::id(shop);
    assert!(shop.df_exists(MembershipTypeKey<MembershipType> { shop_id, name: membership.name }), ENotExists);

    let membership_type: &MembershipType = shop.df_borrow(MembershipTypeKey<MembershipType> { shop_id, name: membership.name });

    membership.image_url = membership_type.image_url;
    membership.version = membership_type.version;
}

// =============== Payment 
public fun new_reciept(shop: &Shop, membership: &Membership, ctx: &mut TxContext): Reciept {
  let membership_type_key = new_membership_type_key(shop, membership.name());
  Reciept {
    id: object::new(ctx),
    shop_id: object::id(shop),
    products: vector<Product>[],
    membership_type: *shop.df_borrow(membership_type_key)
  }
}

public fun pay_with_membership_point(request: &mut PurchaseRequest, membership: &mut Membership, amount: u64) {
  membership.withdraw_membership_points(amount);
  request.add_paid_by_points(amount);
}

public fun pay(market: &mut RetailMarket, policy: &MembershipPolicy, membership: &Option<Membership>, request: &mut PurchaseRequest, payment: &mut Balance<USDC>) {
  if (membership.is_none()){
    let amount = request.price();
    let actual_payment = payment.split(amount);
    market.add_balance(actual_payment);
    request.add_paid(amount);
    // membership 없으면 따로 혜택 적용 안 됨
    return
  };

  if (request.paid_by_points() > 0){
    let amount = request.price() - request.paid_by_points();
    let actual_payment = payment.split(amount);
    market.add_balance(actual_payment);
    request.add_paid(amount);
    // membership point로 쓴 게 있으면 혜택 적용 안 됨
    return
  };

  let amount = request.price();
  let actual_payment = payment.split(amount);
  market.add_balance(actual_payment);
  request.add_paid(amount);
  // membership 혜택 적용하기
  // Rule에 따라 할인 또는 point 추가
}

public fun confirm_purchase_request(request: PurchaseRequest, reciept: &mut Reciept) {
  let (product, price, paid, paid_by_points) = shop::unpack_purchase_request(request);
  assert!(price == paid + paid_by_points, 10);
  reciept.products.push_back(product)
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