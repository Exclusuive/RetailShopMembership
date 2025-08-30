// module exclusuive::membership_policy;

// use sui::balance::{Self, Balance};
// use sui::sui::SUI;
// use sui::vec_set::{Self, VecSet};
// use exclusuive::community::{Community, CommunityCap, get_uid as get_uid_community, get_mut_uid as get_mut_uid_community, require_community_cap};
// use sui::dynamic_object_field;

// public struct MembershipPolicy<phantom T> has key {
//     id : UID,
//     community_id: ID,
//     balance : Balance<SUI>,
//     rules : VecSet<std::type_name::TypeName>,
// }

// public struct TransferRequest<phantom T> has drop {
//     paid : u64,
//     from : ID,
//     receipts : VecSet<std::type_name::TypeName>,
// }

// public struct Rulekey<phantom T : drop> has copy, drop, store {

// }


// public fun new_membership_policy(
//     community: &mut Community,
//     community_cap: &mut CommunityCap,
//     ctx: &mut TxContext
// ) {
//     let id = object::new(ctx);
//     let community_id = object::id(community);
//     let policy = MembershipPolicy { id, community_id, balance: balance::zero<SUI>(), rules: vec_set::empty<std::type_name::TypeName>() };
    
//     dynamic_object_field::add(
//         get_mut_uid_community(community),
//         b"membership_policy",
//         policy,
//     );
// }

// public fun add_rule(
//     policy: &mut MembershipPolicy,
//     community: &mut Community,
//     community_cap: &mut CommunityCap,
//     rule: std::type_name::TypeName,
// ) {
//     require_community_cap(community, community_cap);
//     policy.rules.add(rule);
// }