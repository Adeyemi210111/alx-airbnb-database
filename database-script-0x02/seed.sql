%%Users

INSERT INTO "User" (user_id, first_name, last_name, email, password_hash, phone_number, role)
VALUES
  (gen_random_uuid(), 'Alice', 'Johnson', 'alice@example.com', 'hashed_pw_1', '08012345678', 'guest'),
  (gen_random_uuid(), 'Bob', 'Smith', 'bob@example.com', 'hashed_pw_2', '08023456789', 'host'),
  (gen_random_uuid(), 'Cynthia', 'Lee', 'cynthia@example.com', 'hashed_pw_3', '08034567890', 'host'),
  (gen_random_uuid(), 'David', 'Miller', 'david@example.com', 'hashed_pw_4', '08045678901', 'guest'),
  (gen_random_uuid(), 'Admin', 'User', 'admin@example.com', 'hashed_pw_admin', NULL, 'admin');

%%Properties

-- Assume Bob and Cynthia are hosts
INSERT INTO "Property" (property_id, host_id, name, description, location, pricepernight)
VALUES
  (gen_random_uuid(), 
   (SELECT user_id FROM "User" WHERE email = 'bob@example.com'),
   'Cozy Apartment in Lagos',
   '2-bedroom apartment with WiFi, AC, and close to Victoria Island.',
   'Lagos, Nigeria',
   20000.00),

  (gen_random_uuid(), 
   (SELECT user_id FROM "User" WHERE email = 'cynthia@example.com'),
   'Beachside Villa',
   'Luxury villa with ocean view, 3 bedrooms, pool, and private chef option.',
   'Lekki, Lagos, Nigeria',
   85000.00);

%%Bookings

-- Alice books Bob’s apartment
INSERT INTO "Booking" (booking_id, property_id, user_id, start_date, end_date, total_price, status)
VALUES
  (gen_random_uuid(),
   (SELECT property_id FROM "Property" WHERE name = 'Cozy Apartment in Lagos'),
   (SELECT user_id FROM "User" WHERE email = 'alice@example.com'),
   '2025-09-10',
   '2025-09-15',
   20000 * 5,
   'confirmed');

-- David books Cynthia’s villa
INSERT INTO "Booking" (booking_id, property_id, user_id, start_date, end_date, total_price, status)
VALUES
  (gen_random_uuid(),
   (SELECT property_id FROM "Property" WHERE name = 'Beachside Villa'),
   (SELECT user_id FROM "User" WHERE email = 'david@example.com'),
   '2025-10-01',
   '2025-10-05',
   85000 * 4,
   'pending');

%%Payments

INSERT INTO "Payment" (payment_id, booking_id, amount, payment_method)
VALUES
  (gen_random_uuid(),
   (SELECT booking_id FROM "Booking" WHERE total_price = 100000),
   100000,
   'credit_card'),

  (gen_random_uuid(),
   (SELECT booking_id FROM "Booking" WHERE total_price = 340000),
   340000,
   'paypal');

%%Reviews

-- Alice reviews Bob’s apartment
INSERT INTO "Review" (review_id, property_id, user_id, rating, comment)
VALUES
  (gen_random_uuid(),
   (SELECT property_id FROM "Property" WHERE name = 'Cozy Apartment in Lagos'),
   (SELECT user_id FROM "User" WHERE email = 'alice@example.com'),
   5,
   'Great apartment! Very clean and close to everything.');

-- David has not yet reviewed Cynthia’s villa (booking still pending)

%%Messages

-- Alice sends a message to Bob (the host)
INSERT INTO "Message" (message_id, sender_id, recipient_id, message_body)
VALUES
  (gen_random_uuid(),
   (SELECT user_id FROM "User" WHERE email = 'alice@example.com'),
   (SELECT user_id FROM "User" WHERE email = 'bob@example.com'),
   'Hi Bob, is your apartment available for early check-in?');

-- Bob replies
INSERT INTO "Message" (message_id, sender_id, recipient_id, message_body)
VALUES
  (gen_random_uuid(),
   (SELECT user_id FROM "User" WHERE email = 'bob@example.com'),
   (SELECT user_id FROM "User" WHERE email = 'alice@example.com'),
   'Yes, early check-in is possible. Looking forward to hosting you!');

