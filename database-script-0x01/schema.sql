-- Enable UUID generation (PostgreSQL)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =========
-- ENUM TYPES
-- =========
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'role_enum') THEN
    CREATE TYPE role_enum AS ENUM ('guest', 'host', 'admin');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'booking_status_enum') THEN
    CREATE TYPE booking_status_enum AS ENUM ('pending', 'confirmed', 'canceled');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_method_enum') THEN
    CREATE TYPE payment_method_enum AS ENUM ('credit_card', 'paypal', 'stripe');
  END IF;
END$$;

-- ==========================
-- UPDATED_AT TRIGGER (helper)
-- ==========================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END$$;

-- =====
-- USER
-- =====
CREATE TABLE IF NOT EXISTS "User" (
  user_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name     VARCHAR(100) NOT NULL,
  last_name      VARCHAR(100) NOT NULL,
  email          VARCHAR(255) NOT NULL UNIQUE,
  password_hash  VARCHAR(255) NOT NULL,
  phone_number   VARCHAR(50),
  role           role_enum NOT NULL,
  created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =========
-- PROPERTY
-- =========
CREATE TABLE IF NOT EXISTS "Property" (
  property_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  host_id        UUID NOT NULL,
  name           VARCHAR(200) NOT NULL,
  description    TEXT NOT NULL,
  location       VARCHAR(255) NOT NULL,
  pricepernight  DECIMAL(10,2) NOT NULL,
  created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_property_host
    FOREIGN KEY (host_id) REFERENCES "User"(user_id)
);

-- Keep updated_at fresh on UPDATE (Postgres equivalent of "ON UPDATE CURRENT_TIMESTAMP")
DROP TRIGGER IF EXISTS trg_property_set_updated_at ON "Property";
CREATE TRIGGER trg_property_set_updated_at
BEFORE UPDATE ON "Property"
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- =======
-- BOOKING
-- =======
CREATE TABLE IF NOT EXISTS "Booking" (
  booking_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id  UUID NOT NULL,
  user_id      UUID NOT NULL,
  start_date   DATE NOT NULL,
  end_date     DATE NOT NULL,
  total_price  DECIMAL(12,2) NOT NULL,
  status       booking_status_enum NOT NULL,
  created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_booking_property
    FOREIGN KEY (property_id) REFERENCES "Property"(property_id),
  CONSTRAINT fk_booking_user
    FOREIGN KEY (user_id) REFERENCES "User"(user_id),
  CONSTRAINT chk_booking_dates
    CHECK (end_date > start_date)
);

-- =======
-- PAYMENT
-- =======
CREATE TABLE IF NOT EXISTS "Payment" (
  payment_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id      UUID NOT NULL,
  amount          DECIMAL(12,2) NOT NULL,
  payment_date    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  payment_method  payment_method_enum NOT NULL,

  CONSTRAINT fk_payment_booking
    FOREIGN KEY (booking_id) REFERENCES "Booking"(booking_id)
);

-- ======
-- REVIEW
-- ======
CREATE TABLE IF NOT EXISTS "Review" (
  review_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id  UUID NOT NULL,
  user_id      UUID NOT NULL,
  rating       INTEGER NOT NULL,
  comment      TEXT NOT NULL,
  created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_review_property
    FOREIGN KEY (property_id) REFERENCES "Property"(property_id),
  CONSTRAINT fk_review_user
    FOREIGN KEY (user_id) REFERENCES "User"(user_id),
  CONSTRAINT chk_review_rating
    CHECK (rating >= 1 AND rating <= 5)
);

-- =======
-- MESSAGE
-- =======
CREATE TABLE IF NOT EXISTS "Message" (
  message_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id     UUID NOT NULL,
  recipient_id  UUID NOT NULL,
  message_body  TEXT NOT NULL,
  sent_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_message_sender
    FOREIGN KEY (sender_id) REFERENCES "User"(user_id),
  CONSTRAINT fk_message_recipient
    FOREIGN KEY (recipient_id) REFERENCES "User"(user_id),
  CONSTRAINT chk_message_sender_recipient
    CHECK (sender_id <> recipient_id)
);

-- ==================
-- PERFORMANCE INDEXES
-- ==================

-- User
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_email ON "User"(email);

-- Property
CREATE INDEX IF NOT EXISTS idx_property_host_id ON "Property"(host_id);

-- Booking
CREATE INDEX IF NOT EXISTS idx_booking_property_id ON "Booking"(property_id);
CREATE INDEX IF NOT EXISTS idx_booking_user_id     ON "Booking"(user_id);
CREATE INDEX IF NOT EXISTS idx_booking_status      ON "Booking"(status);
CREATE INDEX IF NOT EXISTS idx_booking_dates       ON "Booking"(start_date, end_date);

-- Payment
CREATE INDEX IF NOT EXISTS idx_payment_booking_id  ON "Payment"(booking_id);

-- Review
CREATE INDEX IF NOT EXISTS idx_review_property_id  ON "Review"(property_id);
CREATE INDEX IF NOT EXISTS idx_review_user_id      ON "Review"(user_id);
CREATE INDEX IF NOT EXISTS idx_review_rating       ON "Review"(rating);

-- Message
CREATE INDEX IF NOT EXISTS idx_message_sender_id   ON "Message"(sender_id);
CREATE INDEX IF NOT EXISTS idx_message_recipient_id ON "Message"(recipient_id);
CREATE INDEX IF NOT EXISTS idx_message_sent_at     ON "Message"(sent_at);
