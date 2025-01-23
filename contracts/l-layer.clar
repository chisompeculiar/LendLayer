;; LendLayer - DeFi Lending Platform
;; Version: 1.0.0

;; Constants
(define-constant MAX_DEPOSIT u1000000000000) 
(define-constant MAX_POOL_SIZE u10000000000000)
(define-constant MIN_COLLATERAL u1000000)

;; Error Codes
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-INSUFFICIENT-BALANCE (err u2))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u3))
(define-constant ERR-POOL-EMPTY (err u4))
(define-constant ERR-INVALID-AMOUNT (err u5))
(define-constant ERR-DEPOSIT-LIMIT (err u6))
(define-constant ERR-POOL-LIMIT (err u7))
(define-constant ERR-MIN-COLLATERAL (err u8))
(define-constant ERR-ACTIVE-LOAN (err u9))

;; Data Variables
(define-data-var total-liquidity uint u0)
(define-data-var interest-rate uint u500) 
(define-data-var collateral-ratio uint u15000)
(define-data-var admin principal tx-sender)
(define-data-var current-epoch uint u0)
(define-data-var interest-accumulated uint u0)

;; Data Maps
(define-map user-deposits principal uint)
(define-map user-borrows principal uint)
(define-map user-collateral principal uint)
(define-map user-last-epoch principal uint)

;; Admin Functions
(define-public (update-interest)
    (let (
        (sender tx-sender)
    )
    (asserts! (is-eq sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (var-set current-epoch (+ (var-get current-epoch) u1))
    (var-set interest-accumulated (+ (var-get interest-accumulated) (var-get interest-rate)))
    (ok true)))

;; Public Functions
(define-public (deposit (amount uint))
    (let (
        (sender tx-sender)
        (current-deposit (default-to u0 (map-get? user-deposits sender)))
        (current-liquidity (var-get total-liquidity))
    )
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= (+ current-deposit amount) MAX_DEPOSIT) ERR-DEPOSIT-LIMIT)
    (asserts! (<= (+ current-liquidity amount) MAX_POOL_SIZE) ERR-POOL-LIMIT)
    
    (try! (stx-transfer? amount sender (as-contract tx-sender)))
    (map-set user-deposits sender (+ current-deposit amount))
    (var-set total-liquidity (+ current-liquidity amount))
    (ok amount)))

(define-public (withdraw (amount uint))
    (let (
        (sender tx-sender)
        (current-deposit (default-to u0 (map-get? user-deposits sender)))
    )
    (asserts! (<= amount current-deposit) ERR-INSUFFICIENT-BALANCE)
    (try! (as-contract (stx-transfer? amount (as-contract tx-sender) sender)))
    (map-set user-deposits sender (- current-deposit amount))
    (var-set total-liquidity (- (var-get total-liquidity) amount))
    (ok amount)))

(define-public (borrow (amount uint))
    (let (
        (sender tx-sender)
        (current-collateral (default-to u0 (map-get? user-collateral sender)))
        (required-collateral (/ (* amount (var-get collateral-ratio)) u10000))
    )
    (asserts! (>= current-collateral required-collateral) ERR-INSUFFICIENT-COLLATERAL)
    (asserts! (<= amount (var-get total-liquidity)) ERR-POOL-EMPTY)
    
    (try! (as-contract (stx-transfer? amount (as-contract tx-sender) sender)))
    (map-set user-borrows sender (+ (default-to u0 (map-get? user-borrows sender)) amount))
    (map-set user-last-epoch sender (var-get current-epoch))
    (var-set total-liquidity (- (var-get total-liquidity) amount))
    (ok amount)))

(define-public (repay (amount uint))
    (let (
        (sender tx-sender)
        (current-borrow (default-to u0 (map-get? user-borrows sender)))
        (borrow-epoch (default-to u0 (map-get? user-last-epoch sender)))
        (epochs-elapsed (- (var-get current-epoch) borrow-epoch))
        (interest-owed (/ (* amount (* epochs-elapsed (var-get interest-rate))) u10000))
    )
    (asserts! (<= amount current-borrow) ERR-INVALID-AMOUNT)
    (try! (stx-transfer? (+ amount interest-owed) sender (as-contract tx-sender)))
    (map-set user-borrows sender (- current-borrow amount))
    (var-set total-liquidity (+ (var-get total-liquidity) amount))
    (ok amount)))

(define-public (deposit-collateral (amount uint))
    (let (
        (sender tx-sender)
    )
    (asserts! (>= amount MIN_COLLATERAL) ERR-MIN-COLLATERAL)
    (try! (stx-transfer? amount sender (as-contract tx-sender)))
    (map-set user-collateral sender (+ (default-to u0 (map-get? user-collateral sender)) amount))
    (ok amount)))

(define-public (withdraw-collateral (amount uint))
    (let (
        (sender tx-sender)
        (current-collateral (default-to u0 (map-get? user-collateral sender)))
        (current-borrow (default-to u0 (map-get? user-borrows sender)))
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
    (map-set user-collateral sender (- current-collateral amount))
    (ok amount)))

;; Read-Only Functions
(define-read-only (get-user-deposit (user principal))
    (ok (default-to u0 (map-get? user-deposits user))))

(define-read-only (get-user-borrow (user principal))
    (let (
        (borrow-amount (default-to u0 (map-get? user-borrows user)))
        (borrow-epoch (default-to u0 (map-get? user-last-epoch user)))
        (epochs-elapsed (- (var-get current-epoch) borrow-epoch))
        (interest-amount (/ (* borrow-amount (* epochs-elapsed (var-get interest-rate))) u10000))
    )
    (ok {
        borrow-amount: borrow-amount,
        interest-owed: interest-amount,
        total-owed: (+ borrow-amount interest-amount)
    })))

(define-read-only (get-collateral-info (user principal))
    (let (
        (collateral (default-to u0 (map-get? user-collateral user)))
        (borrow (default-to u0 (map-get? user-borrows user)))
        (required-collateral (/ (* borrow (var-get collateral-ratio)) u10000))
    )
    (ok {
        collateral-amount: collateral,
        required-collateral: required-collateral,
        withdrawable-amount: (if (> collateral required-collateral)
                                (- collateral required-collateral)
                                u0)
    })))

(define-read-only (get-pool-details)
    (ok {
        total-liquidity: (var-get total-liquidity),
        interest-rate: (var-get interest-rate),
        collateral-ratio: (var-get collateral-ratio),
        current-epoch: (var-get current-epoch),
        interest-accumulated: (var-get interest-accumulated)
    }))