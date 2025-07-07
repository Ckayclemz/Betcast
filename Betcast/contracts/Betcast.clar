;; Betcast Oracle Smart Contract
;; This contract allows users to create cryptocurrency prediction markets,
;; place price bets, resolve forecasts, claim rewards, and handles forecast expiration.

;; Constants
(define-constant ERROR-INVALID-DEADLINE (err u1))
(define-constant ERROR-FORECAST-INACTIVE (err u2))
(define-constant ERROR-FORECAST-FINALIZED (err u3))
(define-constant ERROR-INVALID-STAKE (err u4))
(define-constant ERROR-FORECAST-NOT-EXISTS (err u5))
(define-constant ERROR-INSUFFICIENT-FUNDS (err u6))
(define-constant ERROR-FORECAST-ACTIVE (err u7))
(define-constant ERROR-STAKE-NOT-EXISTS (err u8))
(define-constant ERROR-FORECAST-PENDING (err u9))
(define-constant ERROR-STAKE-LOST (err u10))
(define-constant ERROR-FORECAST-EXPIRED (err u11))
(define-constant ERROR-FORECAST-VALID (err u12))
(define-constant ERROR-UNAUTHORIZED (err u13))
(define-constant ERROR-STAKE-MIN (err u14))
(define-constant ERROR-STAKE-MAX (err u15))
(define-constant ERROR-INVALID-INPUT (err u16))

;; Additional Constants for Validation
(define-constant MAX-BLOCKS-UNTIL-DEADLINE u52560) ;; Maximum ~1 year worth of blocks
(define-constant MIN-BLOCKS-UNTIL-DEADLINE u144)   ;; Minimum ~1 day worth of blocks
(define-constant MAX-BLOCKS-UNTIL-EXPIRY u105120) ;; Maximum ~2 years worth of blocks
(define-constant MIN-QUERY-LENGTH u10)         ;; Minimum query length

;; Data Variables
(define-data-var platform-name (string-ascii 50) "Betcast")
(define-data-var next-crypto-forecast-id uint u1)
(define-data-var oracle-admin principal tx-sender)

;; Configuration
(define-data-var forecast-resolution-window uint u10000)
(define-data-var minimum-stake-amount uint u10)
(define-data-var maximum-stake-amount uint u1000000)

;; Maps
(define-map crypto-forecasts
  { forecast-id: uint }
  {
    query: (string-ascii 256),
    result: (optional bool),
    prediction-deadline: uint,
    resolution-cutoff: uint,
    oracle: principal
  }
)

(define-map crypto-stakes
  { forecast-id: uint, predictor: principal }
  { stake-amount: uint, price-direction: bool }
)

;; Enhanced Private Validation Functions
(define-private (is-valid-forecast-id (forecast-id uint))
  (< forecast-id (var-get next-crypto-forecast-id))
)

(define-private (is-valid-query-length (query (string-ascii 256)))
  (and 
    (>= (len query) MIN-QUERY-LENGTH)
    (<= (len query) u256)
  )
)

(define-private (is-valid-deadline (prediction-deadline uint))
  (let 
    (
      (blocks-until-deadline (- prediction-deadline u0))
    )
    (and
      (>= blocks-until-deadline MIN-BLOCKS-UNTIL-DEADLINE)
      (<= blocks-until-deadline MAX-BLOCKS-UNTIL-DEADLINE)
    )
  )
)

(define-private (is-valid-expiry-time (prediction-deadline uint) (resolution-cutoff uint))
  (let
    (
      (blocks-until-expiry (- resolution-cutoff prediction-deadline))
    )
    (and
      (> resolution-cutoff prediction-deadline)
      (<= blocks-until-expiry MAX-BLOCKS-UNTIL-EXPIRY)
    )
  )
)

(define-private (is-valid-stake-amount (amount uint))
  (and
    (>= amount (var-get minimum-stake-amount))
    (<= amount (var-get maximum-stake-amount))
  )
)

;; Public Functions

;; Create a new crypto forecast with enhanced validation
(define-public (create-crypto-forecast (query (string-ascii 256)) (prediction-deadline uint))
  (let
    (
      (forecast-id (var-get next-crypto-forecast-id))
      (resolution-cutoff (+ prediction-deadline (var-get forecast-resolution-window)))
    )
    ;; Enhanced input validation
    (asserts! (is-valid-query-length query) ERROR-INVALID-INPUT)
    (asserts! (is-valid-deadline prediction-deadline) ERROR-INVALID-DEADLINE)
    (asserts! (is-valid-expiry-time prediction-deadline resolution-cutoff) ERROR-INVALID-INPUT)
    
    (map-set crypto-forecasts
      { forecast-id: forecast-id }
      {
        query: query,
        result: none,
        prediction-deadline: prediction-deadline,
        resolution-cutoff: resolution-cutoff,
        oracle: tx-sender
      }
    )
    (var-set next-crypto-forecast-id (+ forecast-id u1))
    (ok forecast-id)
  )
)

;; Place a stake on a crypto forecast with enhanced validation
(define-public (place-crypto-stake (forecast-id uint) (price-direction bool) (stake-amount uint))
  (let
    (
      (existing-stake (default-to { stake-amount: u0, price-direction: false } 
                      (map-get? crypto-stakes { forecast-id: forecast-id, predictor: tx-sender })))
    )
    ;; Enhanced input validation
    (asserts! (is-valid-forecast-id forecast-id) ERROR-FORECAST-NOT-EXISTS)
    (asserts! (is-valid-stake-amount stake-amount) ERROR-INVALID-STAKE)
    (let
      (
        (forecast (unwrap! (map-get? crypto-forecasts { forecast-id: forecast-id }) ERROR-FORECAST-NOT-EXISTS))
        (total-stake-amount (+ stake-amount (get stake-amount existing-stake)))
      )
      ;; Additional validation for combined stake amount
      (asserts! (<= total-stake-amount (var-get maximum-stake-amount)) ERROR-STAKE-MAX)
      (asserts! (is-none (get result forecast)) ERROR-FORECAST-FINALIZED)
      (asserts! (>= (stx-get-balance tx-sender) stake-amount) ERROR-INSUFFICIENT-FUNDS)
      
      (map-set crypto-stakes
        { forecast-id: forecast-id, predictor: tx-sender }
        { stake-amount: total-stake-amount, price-direction: price-direction }
      )
      (stx-transfer? stake-amount tx-sender (as-contract tx-sender))
    )
  )
)

;; Enhanced setter for forecast resolution window with stricter validation
(define-public (set-forecast-resolution-window (new-window uint))
  (begin
    (asserts! (is-eq tx-sender (var-get oracle-admin)) ERROR-UNAUTHORIZED)
    (asserts! (and 
      (>= new-window u1000)  ;; Minimum ~1 day worth of blocks
      (<= new-window u52560) ;; Maximum ~1 year worth of blocks
    ) ERROR-INVALID-INPUT)
    (ok (var-set forecast-resolution-window new-window))
  )
)

;; Enhanced setter for minimum stake amount with stricter validation
(define-public (set-minimum-stake-amount (new-amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get oracle-admin)) ERROR-UNAUTHORIZED)
    (asserts! (and 
      (>= new-amount u1)
      (< new-amount (var-get maximum-stake-amount))
      (<= new-amount u1000000) ;; Upper limit for minimum stake
    ) ERROR-INVALID-INPUT)
    (ok (var-set minimum-stake-amount new-amount))
  )
)

;; Enhanced setter for maximum stake amount with stricter validation
(define-public (set-maximum-stake-amount (new-amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get oracle-admin)) ERROR-UNAUTHORIZED)
    (asserts! (and 
      (> new-amount (var-get minimum-stake-amount))
      (<= new-amount u1000000000000)
      (>= new-amount u1000) ;; Lower limit for maximum stake
    ) ERROR-INVALID-INPUT)
    (ok (var-set maximum-stake-amount new-amount))
  )
)

;; Getter for oracle admin
(define-read-only (get-oracle-admin)
  (ok (var-get oracle-admin))
)

;; Function to transfer oracle admin rights
(define-public (transfer-oracle-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get oracle-admin)) ERROR-UNAUTHORIZED)
    (asserts! (not (is-eq new-admin (var-get oracle-admin))) ERROR-INVALID-INPUT)
    (ok (var-set oracle-admin new-admin))
  )
) 
