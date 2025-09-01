// module exclusuive::market_tests {
//     use exclusuive::community;
//     use exclusuive::market as m;
//     use sui::test_scenario as ts;
//     use std::string;
//     use sui::coin;
//     use sui::balance;
//     use sui::sui::SUI;

//     const CREATOR: address = @0xC0DE;

//     // ========== Market 생성/중복 ==========
//     #[test]
//     fun test_new_market_success_and_check_exists() {
//         let mut t = ts::begin(CREATOR);

//         // 커뮤니티 생성 (Community 공유 + Cap 전송)
//         community::create_community(string::utf8(b"Com"), string::utf8(b"Desc"), t.ctx());
//         t.next_tx(CREATOR);

//         let mut com: community::Community = t.take_shared();
//         let mut cap: community::CommunityCap = t.take_from_sender();

//         // (의도된 동작) 마켓 없으면 생성 성공
//         // ※ 모듈에서 assert를 !check_market으로 고쳐야 통과
//         m::new_market(&mut com, &mut cap, t.ctx());
//         assert!(m::check_market(&com), 0);

//         ts::return_shared(com);
//         t.return_to_sender(cap);
//         t.end();
//     }

//     // 현재 코드 그대로면, 첫 생성에서 EAlreadyExists로 실패하는 버그 재현용
//     #[test]
//     #[expected_failure(abort_code = m::EAlreadyExists)]
//     fun test_new_market_bug_current_code_expect_fail() {
//         let mut t = ts::begin(CREATOR);
//         community::create_community(string::utf8(b"A"), string::utf8(b"B"), t.ctx());
//         t.next_tx(CREATOR);

//         let mut com: community::Community = t.take_shared();
//         let mut cap: community::CommunityCap = t.take_from_sender();

//         // 현재 구현은 마켓이 없을 때 EAlreadyExists로 abort됨 (역조건)
//         m::new_market(&mut com, &mut cap, t.ctx());
//         // 도달 불가
//         ts::return_shared(com);
//         t.return_to_sender(cap);
//         abort 0xbad
//     }

//     #[test]
//     #[expected_failure(abort_code = m::EAlreadyExists)]
//     fun test_new_market_duplicate_fail() {
//         let mut t = ts::begin(CREATOR);
//         community::create_community(string::utf8(b"Com"), string::utf8(b"Desc"), t.ctx());
//         t.next_tx(CREATOR);

//         let mut com: community::Community = t.take_shared();
//         let mut cap: community::CommunityCap = t.take_from_sender();

//         // (의도) 1회 생성 성공
//         // ※ 구현 수정 필요: !check_market
//         m::new_market(&mut com, &mut cap, t.ctx());
//         assert!(m::check_market(&com), 0);

//         // (의도) 2회 생성 시 EAlreadyExists
//         m::new_market(&mut com, &mut cap, t.ctx());

//         ts::return_shared(com);
//         t.return_to_sender(cap);
//         abort 0xbad
//     }

//     // ========== Product 추가/수정/삭제 ==========
//     #[test]
//     fun test_add_and_edit_product_success() {
//         let mut t = ts::begin(CREATOR);
//         community::create_community(string::utf8(b"Com"), string::utf8(b"Desc"), t.ctx());
//         t.next_tx(CREATOR);

//         let mut com: community::Community = t.take_shared();
//         let mut cap: community::CommunityCap = t.take_from_sender();

//         // 마켓 생성
//         m::new_market(&mut com, &mut cap, t.ctx());

//         // 테스트 헬퍼로 상품 추가 + ID 확보
//         let pid = m::add_product_for_test(
//             &mut com, &mut cap,
//             string::utf8(b"cat"), string::utf8(b"Coffee"),
//             string::utf8(b"tasty"), string::utf8(b"img"), 3000,
//             t.ctx()
//         );

//         // 가변 참조 확보 후 수정
//         let mut p_ref: &mut m::Product = m::borrow_mut_product_by_id_for_test(&mut com, pid);
//         m::edit_product(
//             &mut com, &mut cap, p_ref,
//             string::utf8(b"cat2"), string::utf8(b"Latte"),
//             string::utf8(b"best"), string::utf8(b"img2"), 3500
//         );

//         // 수정 반영 확인 (이름/가격 체크)
//         // p_ref는 여전히 같은 참조
//         assert!(string::as_bytes(&p_ref.name) == string::as_bytes(&string::utf8(b"Latte")), 0);
//         assert!(p_ref.price == 3500, 0);

//         ts::return_shared(com);
//         t.return_to_sender(cap);
//         t.end();
//     }

//     #[test]
//     fun test_delete_product_success() {
//         let mut t = ts::begin(CREATOR);
//         community::create_community(string::utf8(b"Com"), string::utf8(b"Desc"), t.ctx());
//         t.next_tx(CREATOR);

//         let mut com: community::Community = t.take_shared();
//         let mut cap: community::CommunityCap = t.take_from_sender();

//         m::new_market(&mut com, &mut cap, t.ctx());
//         let pid = m::add_product_for_test(
//             &mut com, &mut cap,
//             string::utf8(b"cat"), string::utf8(b"Tea"),
//             string::utf8(b"green"), string::utf8(b"img"), 2000,
//             t.ctx()
//         );

//         // 핸들 확보 → 삭제
//         let mut p_ref: &mut m::Product = m::borrow_mut_product_by_id_for_test(&mut com, pid);
//         m::delete_product(&mut com, &mut cap, p_ref);

//         // 존재 여부 false 확인 (키로 exists_ 체크)
//         let market_ref = m::borrow_mut_market(&mut com);
//         let exists = sui::dynamic_object_field::exists_(
//             &market_ref.id,
//             m::ProductKey { product_id: pid }
//         );
//         assert!(!exists, 0);

//         ts::return_shared(com);
//         t.return_to_sender(cap);
//         t.end();
//     }

//     // ========== 옵션 추가/삭제 & 결제 ==========
//     #[test]
//     fun test_add_remove_option_and_purchase_success() {
//         let mut t = ts::begin(CREATOR);
//         community::create_community(string::utf8(b"Com"), string::utf8(b"Desc"), t.ctx());
//         t.next_tx(CREATOR);

//         let mut com: community::Community = t.take_shared();
//         let mut cap: community::CommunityCap = t.take_from_sender();

//         m::new_market(&mut com, &mut cap, t.ctx());
//         let pid = m::add_product_for_test(
//             &mut com, &mut cap,
//             string::utf8(b"drink"), string::utf8(b"Americano"),
//             string::utf8(b"desc"), string::utf8(b"img"), 3000,
//             t.ctx()
//         );

//         // 옵션 2개 추가 (0: large +500, 1: extra shot +300)
//         let mut p_ref: &mut m::Product = m::borrow_mut_product_by_id_for_test(&mut com, pid);
//         m::add_product_option(&mut com, &mut cap, p_ref, string::utf8(b"size"), string::utf8(b"large"), 500);
//         m::add_product_option(&mut com, &mut cap, p_ref, string::utf8(b"shot"), string::utf8(b"extra"), 300);

//         // 옵션 하나 제거 (예: index 1 제거 → extra shot 삭제)
//         m::remove_product_option(&mut com, &mut cap, p_ref, 1);

//         // 결제 전에 마켓 잔액 확인
//         let market_ref = m::borrow_mut_market(&mut com);
//         let before = balance::value(&market_ref.sui_balance);

//         // 결제: base 3000 + large 500 = 3500
//         let mut opts = vector::empty<u64>();
//         vector::push_back(&mut opts, 0);

//         // 송신자의 Coin<SUI> 확보 (gas 코인)
//         t.next_tx(CREATOR);
//         let mut gas_coin: coin::Coin<SUI> = t.take_from_sender();

//         // 결제 실행
//         m::purchase_product_without_membership(&mut com, p_ref, &opts, &mut gas_coin, t.ctx());

//         let after = balance::value(&market_ref.sui_balance);
//         assert!(after == before + 3500, 0);

//         ts::return_shared(com);
//         t.return_to_sender(cap);
//         // gas_coin은 테스트 종료 시 자동 정리
//         t.end();
//     }

//     #[test]
//     #[expected_failure(abort_code = m::EInsufficientAmount)]
//     fun test_purchase_insufficient_fail() {
//         let mut t = ts::begin(CREATOR);
//         community::create_community(string::utf8(b"Com"), string::utf8(b"Desc"), t.ctx());
//         t.next_tx(CREATOR);

//         let mut com: community::Community = t.take_shared();
//         let mut cap: community::CommunityCap = t.take_from_sender();

//         m::new_market(&mut com, &mut cap, t.ctx());
//         let pid = m::add_product_for_test(
//             &mut com, &mut cap,
//             string::utf8(b"drink"), string::utf8(b"Latte"),
//             string::utf8(b"desc"), string::utf8(b"img"), 4000,
//             t.ctx()
//         );

//         let p_ref    = m::borrow_mut_product_by_id_for_test(&mut com, pid);
//         // 옵션 1개: +1000 → 총 5000
//         m::add_product_option(&mut com, &mut cap, p_ref, string::utf8(b"size"), string::utf8(b"venti"), 1000);

//         let mut opts = vector::empty<u64>();
//         vector::push_back(&mut opts, 0);

//         // 작은 코인으로 결제 시도 (예: 1000만 보유)
//         t.next_tx(CREATOR);
//         let mut sender_coin: coin::Coin<SUI> = t.take_from_sender();
//         // 아주 작은 코인으로 split
//         let tiny: coin::Coin<SUI> = coin::split(&mut sender_coin, 1000, t.ctx());

//         // 총 5000 필요 → 실패해야 함
//         m::purchase_product_without_membership(&mut com, p_ref, &opts, tiny, t.ctx());

//         // 도달 불가
//         ts::return_shared(com);
//         t.return_to_sender(cap);
//         abort 0xbad
//     }
// }
