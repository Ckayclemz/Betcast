#  Betcast - Decentralized Crypto Prediction Market

**Betcast** is a Clarity smart contract that powers decentralized cryptocurrency prediction markets. Users can create forecasts, stake on price directions (up/down), and claim rewards based on outcomes. The platform is fully autonomous, secure, and governed by an oracle administrator.

---

##  Features

-  Create crypto price prediction forecasts
-  Stake on forecasts (price will go **up** or **down**)
-  Forecasts include prediction deadlines and resolution cutoffs
-  Fully on-chain validation with minimum/maximum stake limits
-  Oracle-based result resolution and reward distribution
-  Admin controls for adjusting configuration settings

---

##  Contract Structure

### Key Variables

- `platform-name`: Set to `"Betcast"`
- `next-crypto-forecast-id`: Tracks forecast IDs
- `oracle-admin`: Admin address (creator by default)
- `forecast-resolution-window`: Default time after deadline to resolve a forecast
- `minimum-stake-amount` / `maximum-stake-amount`: Stake limits

### Maps

- `crypto-forecasts`: Stores forecast metadata
- `crypto-stakes`: Stores user stake info on forecasts

---

##  Public Functions

### `create-crypto-forecast (query, prediction-deadline)`
Create a new forecast. Requires:
- `query`: Description (min 10 chars, max 256)
- `prediction-deadline`: Must be within ~1 day to ~1 year in blocks

### `place-crypto-stake (forecast-id, price-direction, stake-amount)`
Stake STX on a forecast:
- `price-direction`: `true` (up) or `false` (down)
- Automatically combines multiple stakes by same user

### `set-forecast-resolution-window (new-window)`
Admin-only: Set resolution window after forecast deadline

### `set-minimum-stake-amount (new-amount)`
Admin-only: Set lower bound for staking

### `set-maximum-stake-amount (new-amount)`
Admin-only: Set upper bound for staking

### `transfer-oracle-admin (new-admin)`
Admin-only: Transfer oracle rights to another principal

### `get-oracle-admin`
Read-only: Returns current admin address

---

##  Validation Rules

- Query length: `10–256` characters
- Deadline must be 144–52560 blocks ahead (~1 day to 1 year)
- Expiry cutoff must be within 105120 blocks (~2 years) of the deadline
- Stake amount must be within the defined limits
- Duplicate stakes add up to a total (must not exceed max)

---

##  Errors

| Code | Description |
|------|-------------|
| `u1`  | Invalid deadline |
| `u4`  | Invalid stake |
| `u5`  | Forecast does not exist |
| `u6`  | Insufficient funds |
| `u13` | Unauthorized admin action |
| `u14` | Below minimum stake |
| `u15` | Exceeds maximum stake |
| `u16` | Invalid input |

> All validations use `asserts!` to ensure contract safety.

---

##  Security & Admin Controls

- Only the `oracle-admin` can update parameters or transfer admin rights
- Admin cannot reset or override forecasts or stakes (immutable history)
- All financial operations use `stx-transfer?` with sender verification

---

##  Deployment Notes

- Contract must be deployed on a Clarity-compatible chain (Stacks)
- The `tx-sender` becomes the initial `oracle-admin`
- Configure staking bounds and resolution window post-deployment

---

##  Future Extensions

-  Oracle integration for auto-resolution via off-chain data feeds
-  Reward distribution for winning predictions
-  Support for additional forecast types (non-crypto events)

---

