module exclusuive::shop_tests {
    use exclusuive::shop;
    use sui::test_scenario as ts;
    use std::string;

    const CREATOR: address = @0xC0DE;
    const OTHER: address   = @0xBEEF;

    /// 1) create_community가 Community(shared)와 CommunityCap(소유자 전송)을 제대로 만드는지 확인
    #[test]
    fun test_create_community_success() {
        let mut t = ts::begin(CREATOR);
        // entry 호출
        shop::create_shop(
            string::utf8(b"ExcluSuive"),
            string::utf8(b"membership infra"),
            t.ctx()
        );

        t.next_tx(CREATOR);

        // 같은 트랜잭션 안에서 share된 Community와 전송된 CommunityCap을 확인
        // (share object는 take_shared로, sender에게 전송된 것은 take_from_sender로 꺼냄)
        let _com: shop::Shop = t.take_shared();
        let _cap: shop::ShopCap = t.take_from_sender();

        // 정리
        // Shared object는 소유권이 없으므로 다시 반환
        ts::return_shared(_com);
        // Cap은 원래 소유자에게 돌려줌
        t.return_to_sender(_cap);

        t.end();
    }

    /// 2) 올바른 CommunityCap으로 add_config 성공 및 DF 존재 확인
    #[test]
    fun test_add_config_success() {
        let mut t = ts::begin(CREATOR);

        // 커뮤니티 생성
        shop::create_shop(
            string::utf8(b"ExcluSuive"),
            string::utf8(b"membership infra"),
            t.ctx()
        );
        t.next_tx(CREATOR);
        
        // Community(shared)와 CommunityCap(소유자 보유) 가져오기
        let mut shop: shop::Shop = t.take_shared();
        let mut cap: shop::ShopCap = t.take_from_sender();

        // add_config 실행
        let type_name = string::utf8(b"payment");
        let content   = string::utf8(b"enable-stablecoin-benefits");
        shop::add_config(&mut shop, &mut cap, type_name, content);

        // dynamic_field 존재 확인
        // 키/값 타입은 community 모듈의 제네릭 키와 값 타입을 그대로 사용
        let exists = shop::check_config(&shop, type_name);
        assert!(exists, 0);

        // 정리
        ts::return_shared(shop);
        t.return_to_sender(cap);

        t.end();
    }

    /// 3) 잘못된 CommunityCap으로 add_config 호출 시 ENotAuthorized로 abort 확인
    #[test]
    #[expected_failure(abort_code = shop::ENotAuthorized)]
    fun test_add_config_with_wrong_cap_fail() {
        let mut t = ts::begin(CREATOR);

        // 올바른 커뮤니티 생성 (이 커뮤니티에 묶인 cap이 아님)
        shop::create_shop(
            string::utf8(b"Main"),
            string::utf8(b"desc"),
            t.ctx()
        );
        t.next_tx(OTHER);
        // 공유 커뮤니티 꺼내기
        let mut shop: shop::Shop = t.take_shared();

        // ❌ 커뮤니티와 무관한 cap 생성 (테스트 전용 함수)
        shop::create_shop(
            string::utf8(b"asdfasdf"),
            string::utf8(b"desc"),
            t.ctx()
        );
        t.next_tx(OTHER);
        let mut wrong_cap: shop::ShopCap = t.take_from_sender();

        // 권한 체크에 걸려 abort되어야 함
        shop::add_config(
            &mut shop,
            &mut wrong_cap,
            string::utf8(b"payment"),
            string::utf8(b"should-fail")
        );

        // 도달 불가
        ts::return_shared(shop);
        t.return_to_sender(wrong_cap);
        abort 0xbad
    }

    /// (선택) require_community_cap 직접 호출로도 동일한 abort 확인
    #[test]
    #[expected_failure(abort_code = shop::ENotAuthorized)]
    fun test_require_cap_direct_fail() {
        let mut t = ts::begin(CREATOR);

        shop::create_shop(
            string::utf8(b"Main"),
            string::utf8(b"desc"),
            t.ctx()
        );
        t.next_tx(OTHER);


        let mut shop: shop::Shop = t.take_shared();
        shop::create_shop(
            string::utf8(b"asdfasdf"),
            string::utf8(b"desc"),
            t.ctx()
        );
        t.next_tx(OTHER);
        let mut wrong_cap: shop::ShopCap = t.take_from_sender();

        // 여기서 바로 abort
        shop::require_shop_cap(&mut shop, &mut wrong_cap);

        ts::return_shared(shop);
        t.return_to_sender(wrong_cap);
        abort 0xbad
    }

    #[test]
    fun test_add_config_content_verify() {
        let mut t = ts::begin(CREATOR);

        // 1) 커뮤니티 생성
        shop::create_shop(
            string::utf8(b"ExcluSuive"),
            string::utf8(b"membership infra"),
            t.ctx()
        );
        t.next_tx(CREATOR);
        // 2) 공유 Community / 소유 Cap 취득
        let mut shop: shop::Shop = t.take_shared();
        let mut cap: shop::ShopCap = t.take_from_sender();

        // 3) config 추가
        let type_name = string::utf8(b"payment");
        let content   = string::utf8(b"enable-stablecoin-benefits");
        shop::add_config(&mut shop, &mut cap, type_name, content);

        //    immutable borrow로 읽어서 content 비교
        let cfg_ref: &shop::ConfigType = shop::get_config(&shop, type_name);

        // 5) content == "enable-stablecoin-benefits" 확인
        let expect = string::utf8(b"enable-stablecoin-benefits");
        assert!(
            string::as_bytes(shop::get_config_content(cfg_ref)) == string::as_bytes(&expect),
            0
        );

        // 정리
        ts::return_shared(shop);
        t.return_to_sender(cap);
        t.end();
    }
}
