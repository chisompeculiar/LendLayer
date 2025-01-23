;; LendLayer - DeFi Lending Platform
;; Version: 1.0.0

;; Constants & Errors
(define-constant MAX_DEPOSIT u1000000000000)
(define-constant MAX_POOL_SIZE u10000000000000)
(define-constant MIN_COLLATERAL u1000000)
(define-constant LIQUIDATION_THRESHOLD u13000)
(define-constant LIQUIDATION_BONUS u500)

(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-INSUFFICIENT-BALANCE (err u2))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u3))
(define-constant ERR-POOL-EMPTY (err u4))
(define-constant ERR-INVALID-AMOUNT (err u5))
(define-constant ERR-DEPOSIT-LIMIT (err u6))
(define-constant ERR-POOL-LIMIT (err u7))
(define-constant ERR-MIN-COLLATERAL (err u8))
(define-constant ERR-ACTIVE-LOAN (err u9))
(define-constant ERR-NOT-LIQUIDATABLE (err u10))
(define-constant ERR-ALREADY-LIQUIDATED (err u11))

;; Variables
(define-data-var total-liquidity uint u0)
(define-data-var interest-rate uint u500)
(define-data-var collateral-ratio uint u15000)
(define-data-var admin principal tx-sender)
(define-data-var current-epoch uint u0)
(define-data-var interest-accumulated uint u0)

;; Maps
(define-map deposits principal uint)
(define-map borrows principal uint)
(define-map collateral principal uint)
(define-map last-epoch principal uint)

;; Admin Functions
(define-public (update-interest)
    (let ((sender tx-sender))
        (asserts! (is-eq sender (var-get admin)) ERR-NOT-AUTHORIZED)
        (var-set current-epoch (+ (var-get current-epoch) u1))
        (var-set interest-accumulated (+ (var-get interest-accumulated) (var-get interest-rate)))
        (ok true)))

;; Core Functions
(define-public (deposit (amount uint))
    (let (
        (sender tx-sender)
        (current-deposit (default-to u0 (map-get? deposits sender)))
    )
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= (+ current-deposit amount) MAX_DEPOSIT) ERR-DEPOSIT-LIMIT)
    (try! (stx-transfer? amount sender (as-contract tx-sender)))
    (map-set deposits sender (+ current-deposit amount))
    (var-set total-liquidity (+ (var-get total-liquidity) amount))
    (ok amount)))

(define-public (borrow (amount uint))
    (let (
        (sender tx-sender)
        (current-collateral (default-to u0 (map-get? collateral sender)))
        (required-collateral (/ (* amount (var-get collateral-ratio)) u10000))
    )
    (asserts! (>= current-collateral required-collateral) ERR-INSUFFICIENT-COLLATERAL)
    (asserts! (<= amount (var-get total-liquidity)) ERR-POOL-EMPTY)
    (try! (as-contract (stx-transfer? amount (as-contract tx-sender) sender)))
    (map-set borrows sender (+ (default-to u0 (map-get? borrows sender)) amount))
    (map-set last-epoch sender (var-get current-epoch))
    (var-set total-liquidity (- (var-get total-liquidity) amount))
    (ok amount)))

(define-public (repay (amount uint))
    (let (
        (sender tx-sender)
        (current-borrow (default-to u0 (map-get? borrows sender)))
        (borrow-epoch (default-to u0 (map-get? last-epoch sender)))
        (epochs-elapsed (- (var-get current-epoch) borrow-epoch))
        (interest-owed (/ (* amount (* epochs-elapsed (var-get interest-rate))) u10000))
    )
    (asserts! (<= amount current-borrow) ERR-INVALID-AMOUNT)
    (try! (stx-transfer? (+ amount interest-owed) sender (as-contract tx-sender)))
    (map-set borrows sender (- current-borrow amount))
    (var-set total-liquidity (+ (var-get total-liquidity) amount))
    (ok amount)))

;; Collateral Functions
(define-public (deposit-collateral (amount uint))
    (let ((sender tx-sender))
        (asserts! (>= amount MIN_COLLATERAL) ERR-MIN-COLLATERAL)
        (try! (stx-transfer? amount sender (as-contract tx-sender)))
        (map-set collateral 
            sender 
            (+ (default-to u0 (map-get? collateral sender)) amount))
        (ok amount)))

(define-public (withdraw-collateral (amount uint))
    (let (
        (sender tx-sender)
        (current-collateral (default-to u0 (map-get? collateral sender)))
        (current-borrow (default-to u0 (map-get? borrows sender)))
        (required-collateral (/ (* current-borrow (var-get collateral-ratio)) u10000))
    )
    (asserts! (<= amount current-collateral) ERR-INSUFFICIENT-COLLATERAL)
    (asserts! 
        (or 
            (is-eq current-borrow u0)
            (>= (- current-collateral amount) required-collateral)
        )
        ERR-ACTIVE-LOAN
    )
    (try! (as-contract (stx-transfer? amount (as-contract tx-sender) sender)))
    (map-set collateral sender (- current-collateral amount))
    (ok amount)))

;; Liquidation Function
(define-public (liquidate (target principal))
    (let (
        (liquidator tx-sender)
        (target-collateral (default-to u0 (map-get? collateral target)))
        (target-borrow (default-to u0 (map-get? borrows target)))
        (current-ratio (/ (* target-collateral u10000) target-borrow))
        (bonus-amount (/ (* target-collateral LIQUIDATION_BONUS) u10000))
        (liquidation-amount (+ target-collateral bonus-amount))
    )
    (asserts! (< current-ratio LIQUIDATION_THRESHOLD) ERR-NOT-LIQUIDATABLE)
    (asserts! (> target-borrow u0) ERR-ALREADY-LIQUIDATED)
    
    (try! (stx-transfer? target-borrow liquidator (as-contract tx-sender)))
    (try! (as-contract (stx-transfer? liquidation-amount (as-contract tx-sender) liquidator)))
    
    (map-set borrows target u0)
    (map-set collateral target u0)
    (map-set last-epoch target u0)
    
    (ok true)))

;; Read-Only Functions
(define-read-only (get-user-deposit (user principal))
    (ok (default-to u0 (map-get? deposits user))))

(define-read-only (get-user-borrow (user principal))
    (let (
        (borrow-amount (default-to u0 (map-get? borrows user)))
        (borrow-epoch (default-to u0 (map-get? last-epoch user)))
        (epochs-elapsed (- (var-get current-epoch) borrow-epoch))
        (interest-amount (/ (* borrow-amount (* epochs-elapsed (var-get interest-rate))) u10000))
    )
    (ok {
        borrow-amount: borrow-amount,
        interest-owed: interest-amount,
        total-owed: (+ borrow-amount interest-amount)
    })))

(define-read-only (get-pool-details)
    (ok {
        total-liquidity: (var-get total-liquidity),
        interest-rate: (var-get interest-rate),
        collateral-ratio: (var-get collateral-ratio),
        current-epoch: (var-get current-epoch),
        interest-accumulated: (var-get interest-accumulated)
    }))