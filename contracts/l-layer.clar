;; LendLayer - DeFi Lending Platform
;; Version: 1.0.0

(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-INSUFFICIENT-BALANCE (err u2))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u3))
(define-constant ERR-POOL-EMPTY (err u4))
(define-constant ERR-INVALID-AMOUNT (err u5))
(define-constant ERR-DEPOSIT-LIMIT (err u6))
(define-constant ERR-POOL-LIMIT (err u7))

;; Constants
(define-constant MAX_DEPOSIT u1000000000000) ;; 1 million STX
(define-constant MAX_POOL_SIZE u10000000000000) ;; 10 million STX

;; Data Variables
(define-data-var total-liquidity uint u0)
(define-data-var interest-rate uint u500) ;; 5% represented as basis points
(define-data-var collateral-ratio uint u15000) ;; 150% represented as basis points

;; Data Maps
(define-map user-deposits principal uint)
(define-map user-borrows principal uint)
(define-map user-collateral principal uint)

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
    (var-set total-liquidity (- (var-get total-liquidity) amount))
    (ok amount)))

;; Read-Only Functions
(define-read-only (get-user-deposit (user principal))
    (ok (default-to u0 (map-get? user-deposits user))))

(define-read-only (get-user-borrow (user principal))
    (ok (default-to u0 (map-get? user-borrows user))))

(define-read-only (get-pool-details)
    (ok {
        total-liquidity: (var-get total-liquidity),
        interest-rate: (var-get interest-rate),
        collateral-ratio: (var-get collateral-ratio)
    }))