module exclusuive::membership_tests {
    use exclusuive::shop;
    use exclusuive::membership as em;
    use sui::test_scenario as ts;
    use std::string;

    const CREATOR: address = @0xC0DE;

    /// 1) MembershipType 등록 성공
    #[test]
    fun test_new_membership_type_success() {
        let mut t = ts::begin(CREATOR);

        // 커뮤니티 생성
        shop::create_shop(
            string::utf8(b"Main"),
            string::utf8(b"desc"),
            t.ctx()
        );
        t.next_tx(CREATOR);

        let mut shop: shop::Shop = t.take_shared();
        let mut cap: shop::ShopCap = t.take_from_sender();

        // 타입 등록
        em::new_membership_type(
            &mut shop,
            &mut cap,
            string::utf8(b"VIP"),
            string::utf8(b"vip_img"),
            true,
            option::none(),
        );

        // 존재 확인
        let membership_type_key = em::new_membership_type_key(&shop, string::utf8(b"VIP"));
        let exists = shop.df_exists(membership_type_key);
        assert!(exists, 0);

        ts::return_shared(shop);
        t.return_to_sender(cap);
        t.end();
    }

    /// 2) MembershipType 중복 등록 실패 (EAlreadyExists)
    #[test]
    #[expected_failure(abort_code = em::EAlreadyExists)]
    fun test_new_membership_type_duplicate_fail() {
        let mut t = ts::begin(CREATOR);

        shop::create_shop(string::utf8(b"Main"), string::utf8(b"desc"), t.ctx());
        t.next_tx(CREATOR);
        let mut shop: shop::Shop = t.take_shared();
        let mut cap: shop::ShopCap = t.take_from_sender();

        em::new_membership_type(&mut shop, &mut cap, string::utf8(b"VIP"), string::utf8(b"url"), true, option::none());
        // 같은 이름 다시 등록 → 실패
        em::new_membership_type(&mut shop, &mut cap, string::utf8(b"VIP"), string::utf8(b"url2"), true, option::none());

        ts::return_shared(shop);
        t.return_to_sender(cap);
        abort 0xbad
    }

    /// 3) MembershipType 업데이트 성공
    #[test]
    fun test_update_membership_type_success() {
        let mut t = ts::begin(CREATOR);

        shop::create_shop(string::utf8(b"Main"), string::utf8(b"desc"), t.ctx());
        t.next_tx(CREATOR);
        let mut shop: shop::Shop = t.take_shared();
        let mut cap: shop::ShopCap = t.take_from_sender();

        // 등록
        em::new_membership_type(&mut shop, &mut cap, string::utf8(b"VIP"), string::utf8(b"url1"), true, option::none());
        // 업데이트
        em::update_membership_type(&mut shop, &mut cap, string::utf8(b"VIP"), string::utf8(b"url2"), false, option::some(100));


        // assert!(string::as_bytes(&em::get_membership_type_image_url(&mut shop, string::utf8(b"VIP"))) == string::as_bytes(&string::utf8(b"url2")), 0);
        assert!(string::as_bytes(&em::mt_image_url(&shop, string::utf8(b"VIP"))) == string::as_bytes(&string::utf8(b"url2")), 0);

        ts::return_shared(shop);
        t.return_to_sender(cap);
        t.end();
    }

    /// 4) 존재하지 않는 MembershipType 업데이트 실패 (ENotExists)
    #[test]
    #[expected_failure(abort_code = em::ENotExists)]
    fun test_update_membership_type_not_exist_fail() {
        let mut t = ts::begin(CREATOR);

        shop::create_shop(string::utf8(b"Main"), string::utf8(b"desc"), t.ctx());
        t.next_tx(CREATOR);
        let mut shop: shop::Shop = t.take_shared();
        let mut cap: shop::ShopCap = t.take_from_sender();

        // 등록 없이 업데이트 시도
        em::update_membership_type(&mut shop, &mut cap, string::utf8(b"VIP"), string::utf8(b"url"), true, option::none());

        ts::return_shared(shop);
        t.return_to_sender(cap);
        abort 0xbad
    }

    /// 5) Membership 발급 성공
    #[test]
    fun test_new_membership_success() {
        let mut t = ts::begin(CREATOR);

        shop::create_shop(string::utf8(b"Main"), string::utf8(b"desc"), t.ctx());
        t.next_tx(CREATOR);
        let mut shop: shop::Shop = t.take_shared();
        let mut cap: shop::ShopCap = t.take_from_sender();

        // 타입 등록
        em::new_membership_type(&mut shop, &mut cap, string::utf8(b"VIP"), string::utf8(b"url"), true, option::none());

        // membership 발급
        let m: em::Membership = em::new_membership(&mut shop, &mut cap, string::utf8(b"VIP"), t.ctx());
        assert!(string::as_bytes(&m.name()) == string::as_bytes(&string::utf8(b"VIP")), 0);
        transfer::public_transfer(m, t.sender());   
        ts::return_shared(shop);
        t.return_to_sender(cap);
        t.end();
    }

    /// 6) 존재하지 않는 MembershipType으로 Membership 발급 실패 (ENotExists)
    #[test]
    #[expected_failure(abort_code = em::ENotExists)]
    fun test_new_membership_type_not_exist_fail() {
        let mut t = ts::begin(CREATOR);

        shop::create_shop(string::utf8(b"Main"), string::utf8(b"desc"), t.ctx());
        t.next_tx(CREATOR);
        let mut shop: shop::Shop = t.take_shared();
        let mut cap: shop::ShopCap = t.take_from_sender();

        // 등록하지 않고 발급 → 실패
        let _m = em::new_membership(&mut shop, &mut cap, string::utf8(b"VIP"), t.ctx());

        ts::return_shared(shop);
        t.return_to_sender(cap);
        abort 0xbad
    }

    /// 7) MembershipType 업데이트 후 Membership 동기화 확인
    #[test]
    fun test_update_membership_sync_success() {
        let mut t = ts::begin(CREATOR);

        shop::create_shop(string::utf8(b"Main"), string::utf8(b"desc"), t.ctx());
        t.next_tx(CREATOR);
        let mut shop: shop::Shop = t.take_shared();
        let mut cap: shop::ShopCap = t.take_from_sender();

        // 타입 등록
        em::new_membership_type(&mut shop, &mut cap, string::utf8(b"VIP"), string::utf8(b"url1"), true, option::none());

        // membership 발급
        let mut m: em::Membership = em::new_membership(&mut shop, &mut cap, string::utf8(b"VIP"), t.ctx());

        // 타입 업데이트
        em::update_membership_type(&mut shop, &mut cap, string::utf8(b"VIP"), string::utf8(b"url2"), false, option::some(50));

        // membership 동기화
        em::update_membership(&mut shop, &mut m);

        assert!(string::as_bytes(&m.image_url()) == string::as_bytes(&string::utf8(b"url2")), 0);
        transfer::public_transfer(m, t.sender());   
        ts::return_shared(shop);
        t.return_to_sender(cap);
        t.end();
    }
}
