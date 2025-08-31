
# Normalization to Third Normal Form (3NF) — Airbnb Clone DB

This note documents how the current schema was reviewed against **1NF → 2NF → 3NF** and the adjustments made to remove redundancy, avoid update anomalies, and improve data integrity.

> Scope covers the existing entities: **User, Property, Booking, Payment, Review, Message**.

---

## 1) Method: 1NF → 2NF → 3NF Checks

### First Normal Form (1NF)
- **Rule:** Each column holds atomic (indivisible) values; no repeating groups; each row is unique.
- **Findings:**
  - `User`, `Booking`, `Payment`, `Review`, `Message` use atomic columns and single-column PKs (UUIDs) → OK.
  - `Property.location` is a single string that likely encodes multiple sub-values (street, city, state, country, lat/long). While still “atomic” as a string, it’s **not decomposed** and can cause search/update anomalies.
- **Action:** Split `Property.location` into **structured address fields** (see design changes below).

### Second Normal Form (2NF)
- **Rule:** No partial dependency of non-key attributes on a part of a composite key. (All tables here have **single-column** primary keys.)
- **Findings:** No composite PKs → **No 2NF violations.**

### Third Normal Form (3NF)
- **Rule:** No transitive dependencies: non-key attributes must depend **only** on the table’s primary key.
- **Findings & Actions:**
  1. **Review(Property, User)**  
     - Current: `Review(property_id, user_id, ...)`  
     - Risk: If we also need to ensure the reviewer actually stayed at the property, we end up relating `Review` to a `Booking`. In that case, having **both** `booking_id` and `property_id` would introduce a transitive dependency because `property_id` is functionally determined by `booking_id` (via `Booking.property_id`).  
     - **Fix:** Move `Review` to rely on `booking_id` and `author_id` (user), and **drop `property_id`** from `Review`. Property can be obtained through the booking. This removes redundancy and enforces “review comes from a stay.”
  2. **Booking.total_price**  
     - `total_price` is a **derived** value (duration × price at time of booking, plus fees/taxes). Keeping it is not a 3NF violation (it depends on the key), but it can cause update anomalies.  
     - **Mitigation:** Snapshot pricing inputs at booking time (e.g., `nightly_rate_snapshot`, `cleaning_fee_snapshot`, `tax_snapshot`) and either:  
       - compute `total_price` at query-time, or  
       - **store** `total_price` along with snapshots and treat it as a **fact** of the transaction.  
     - This avoids future changes in `Property.pricepernight` from corrupting historical totals.
  3. **Payment.payment_method**  
     - Values mix **providers** (`stripe`, `paypal`) and **channel** (`credit_card`).  
     - **Optional normalization:** Split into `payment_provider` (`stripe`, `paypal`, etc.) and `payment_channel` (`card`, `wallet`, `bank_transfer`…), or introduce a `PaymentMethod` lookup table. This is not a strict 3NF violation but reduces inconsistent values and eases validation/reporting.

---

## 2) Design Changes (Resulting 3NF Schema)

### A. Property Address Normalization
Replace `Property.location` with **structured fields**:
- `street_address` (VARCHAR, NOT NULL)
- `city` (VARCHAR, NOT NULL)
- `state_region` (VARCHAR, NULL/NOT NULL per country)
- `postal_code` (VARCHAR, NULL)
- `country` (VARCHAR, NOT NULL)
- `latitude` (DECIMAL, NULL)  
- `longitude` (DECIMAL, NULL)

> Rationale: Eliminates embedded multi-part values, improves filtering (e.g., city-wide search), and reduces update errors.

> _Optional:_ If you expect many properties to share the same city/region and want referential integrity on places, introduce a `Location` table and reference it from `Property`. This is not required for 3NF but can help with data quality at scale.

### B. Review Tied to Booking (Remove Redundancy)
Rework `Review` to use `booking_id` and `author_id`:
- `review_id` (PK)
- `booking_id` (FK → `Booking.booking_id`, NOT NULL)
- `author_id` (FK → `User.user_id`, NOT NULL)
- `rating` (INT, 1..5, NOT NULL)
- `comment` (TEXT, NOT NULL)
- `created_at` (TIMESTAMP, DEFAULT CURRENT_TIMESTAMP)

**Constraints:**
- Ensure the booking is completed before allowing a review.
- Ensure the author is either the booking’s guest (minimal model) or guest/host (bi-directional review model).
- **Uniqueness:** `(booking_id, author_id)` unique to prevent duplicate reviews by the same person for the same stay.

> _Note:_ Since `Booking` already has `property_id`, we **don’t need** `Review.property_id`. Use joins to fetch property info when needed.

### C. Booking Price Snapshot (Avoid Anomalies)
Keep historical accuracy by snapshotting pricing inputs when a booking is created:
- Add columns to `Booking`:  
  - `nightly_rate_snapshot` (DECIMAL, NOT NULL)  
  - `currency` (e.g., `NGN`, `USD`)  
  - Optional: `fees_snapshot` (JSON) or separate columns (`cleaning_fee_snapshot`, `service_fee_snapshot`, `tax_snapshot`).
- Choose either:
  - (i) **Compute on read**: Derive `total_price` at query-time using snapshots and date difference; or
  - (ii) **Store on write**: Persist `total_price` and validate via triggers or application logic.

Either approach is 3NF-compliant because all values still depend only on `booking_id`.

### D. Payment Method Normalization (Optional but Recommended)
Replace `payment_method` ENUM with clearer columns or a lookup:
- Option 1: Columns: `payment_provider` (ENUM: `stripe`, `paypal`, ...), `payment_channel` (ENUM: `card`, `wallet`, `bank_transfer`, ...)
- Option 2: `PaymentMethod` lookup: `(id, provider, channel, display_name, is_active)` and reference `payment_method_id` from `Payment`.

This reduces ambiguity and enables validation and reporting without parsing mixed semantics.

---

## 3) SQL DDL Patches (Illustrative)

> The exact syntax may vary by RDBMS (PostgreSQL vs MySQL).

### A. Property Address
```sql
-- Replace 'location' with structured fields
ALTER TABLE Property
  DROP COLUMN location,
  ADD COLUMN street_address VARCHAR(255) NOT NULL,
  ADD COLUMN city VARCHAR(100) NOT NULL,
  ADD COLUMN state_region VARCHAR(100),
  ADD COLUMN postal_code VARCHAR(20),
  ADD COLUMN country VARCHAR(100) NOT NULL,
  ADD COLUMN latitude DECIMAL(10, 7),
  ADD COLUMN longitude DECIMAL(10, 7);
```

### B. Review Rework
```sql
-- New structure for Review
ALTER TABLE Review
  ADD COLUMN booking_id UUID NOT NULL,
  ADD COLUMN author_id UUID NOT NULL,
  DROP COLUMN property_id,
  DROP COLUMN user_id;

-- FKs
ALTER TABLE Review
  ADD CONSTRAINT fk_review_booking
    FOREIGN KEY (booking_id) REFERENCES Booking(booking_id),
  ADD CONSTRAINT fk_review_author
    FOREIGN KEY (author_id) REFERENCES "User"(user_id);

-- Uniqueness per stay per author
CREATE UNIQUE INDEX uq_review_booking_author
  ON Review(booking_id, author_id);
```

### C. Booking Snapshots
```sql
ALTER TABLE Booking
  ADD COLUMN nightly_rate_snapshot DECIMAL(10,2) NOT NULL,
  ADD COLUMN currency VARCHAR(3) NOT NULL DEFAULT 'NGN';
-- Optional fees/taxes snapshots
-- ALTER TABLE Booking ADD COLUMN cleaning_fee_snapshot DECIMAL(10,2);
-- ALTER TABLE Booking ADD COLUMN service_fee_snapshot DECIMAL(10,2);
-- ALTER TABLE Booking ADD COLUMN tax_snapshot DECIMAL(10,2);

-- If you choose to persist total_price:
-- Ensure application or trigger maintains it from snapshots + dates
```

### D. Payment Method (Option 1)
```sql
ALTER TABLE Payment
  DROP COLUMN payment_method,
  ADD COLUMN payment_provider VARCHAR(20) NOT NULL, -- e.g., 'stripe', 'paypal'
  ADD COLUMN payment_channel VARCHAR(20) NOT NULL;  -- e.g., 'card', 'wallet', 'bank_transfer'

-- Optional check constraints
-- CHECK (payment_provider IN ('stripe','paypal')),
-- CHECK (payment_channel IN ('card','wallet','bank_transfer'));
```

### D'. Payment Method (Option 2 — Lookup)
```sql
CREATE TABLE PaymentMethod (
  id UUID PRIMARY KEY,
  provider VARCHAR(20) NOT NULL,
  channel VARCHAR(20) NOT NULL,
  display_name VARCHAR(50) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
);

ALTER TABLE Payment
  ADD COLUMN payment_method_id UUID NOT NULL,
  ADD CONSTRAINT fk_payment_method
    FOREIGN KEY (payment_method_id) REFERENCES PaymentMethod(id);
```

---

## 4) Integrity & Constraints (Non-NF but Critical)

- **Non-overlapping bookings per property:**  
  - PostgreSQL: exclusion constraint on daterange:  
    ```sql
    ALTER TABLE Booking
      ADD CONSTRAINT no_overlap
      EXCLUDE USING gist (
        property_id WITH =,
        daterange(start_date, end_date, '[]') WITH &&
      );
    ```
  - MySQL: enforce via locking + application logic or triggers.
- **Host role constraint:** ensure `Property.host_id` points to a `User.role = 'host'` (via check or trigger).
- **Review timing:** Only allow reviews after `Booking.end_date` and when booking status = 'completed' (application or trigger).

---

## 5) Summary of 3NF Status

- All entities have attributes depending **only on their PKs** (no transitive dependencies).
- Redundant references removed (e.g., `Review.property_id` dropped in favor of `booking_id`).
- Multi-part `location` decomposed to atomic address fields.
- Derived price handled safely via snapshots (and optional stored totals).  
- Payment method semantics clarified to avoid inconsistent values.

This achieves a clean **3NF** design while preserving historical accuracy and operational integrity for a booking platform.
