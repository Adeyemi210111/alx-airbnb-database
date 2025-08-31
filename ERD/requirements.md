ER Diagram

USER {
uuid user_id PK
string first_name
string last_name
string email UNIQUE
string password_hash
string phone_number
enum role "guest | host | admin"
timestamp created_at
}

PROPERTY {
uuid property_id PK
uuid host_id FK "→ USER.user_id"
string name
text description
string location
decimal pricepernight
timestamp created_at
timestamp updated_at
}

BOOKING {
uuid booking_id PK
uuid property_id FK "→ PROPERTY.property_id"
uuid user_id FK "→ USER.user_id"
date start_date
date end_date
decimal total_price
enum status "pending | confirmed | canceled"
timestamp created_at
}

PAYMENT {
uuid payment_id PK
uuid booking_id FK "→ BOOKING.booking_id"
decimal amount
timestamp payment_date
enum payment_method "credit_card | paypal | stripe"
}

REVIEW {
uuid review_id PK
uuid property_id FK "→ PROPERTY.property_id"
uuid user_id FK "→ USER.user_id"
int rating "1..5 CHECK"
text comment
timestamp created_at
}

MESSAGE {
uuid message_id PK
uuid sender_id FK "→ USER.user_id"
uuid recipient_id FK "→ USER.user_id"
text message_body
timestamp sent_at
}

%% Relationships (cardinality)
USER ||--o{ PROPERTY : "hosts"
USER ||--o{ BOOKING : "makes"
PROPERTY ||--o{ BOOKING : "has"
BOOKING ||--o{ PAYMENT : "generates"
PROPERTY ||--o{ REVIEW : "receives"
USER ||--o{ REVIEW : "writes"
USER ||--o{ MESSAGE : "sends"
USER ||--o{ MESSAGE : "receives"

%% Notes / Constraints (visual only)
%% - Unique: USER.email
%% - Indexes: user_id, property_id, booking_id (PKs auto); email on USER; property_id on PROPERTY & BOOKING; booking_id on BOOKING & PAYMENT
%% - Non-overlapping bookings should be enforced per property at the application/DB constraint level
<img width="672" height="355" alt="Screenshot 2025-08-31 at 4 56 23 PM" src="https://github.com/user-attachments/assets/478514ac-c07c-406b-a24d-e5e89843e7e8" />


