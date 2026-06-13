-- ========================================================================================
-- WASLA SMART CLASSIFIEDS PLATFORM - MAMP PREVIEW SCHEMA (MySQL Version)
-- ========================================================================================
-- ⚠️ تحذير تقني (CTO Warning): 
-- هذا الملف مخصص فقط "للمعاينة" على برنامج MAMP (phpMyAdmin).
-- تم تحويل الأكواد من PostgreSQL إلى MySQL لكي تتمكن من رؤية الهيكل على متصفح اللوكال هوست.
-- في مرحلة الإنتاج الحقيقية، يجب استخدام ملفات الـ PostgreSQL الأساسية.
-- ========================================================================================

-- 1. GEO (الجغرافيا)
CREATE TABLE governorates (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name_ar VARCHAR(50) NOT NULL,
    name_en VARCHAR(50) NOT NULL
);

CREATE TABLE cities (
    id INT AUTO_INCREMENT PRIMARY KEY,
    governorate_id INT,
    name_ar VARCHAR(50) NOT NULL,
    name_en VARCHAR(50) NOT NULL,
    FOREIGN KEY (governorate_id) REFERENCES governorates(id) ON DELETE CASCADE
);

CREATE TABLE districts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    city_id INT,
    name_ar VARCHAR(50) NOT NULL,
    name_en VARCHAR(50) NOT NULL,
    FOREIGN KEY (city_id) REFERENCES cities(id) ON DELETE CASCADE
);

-- 2. AUTH & SECURITY (المصادقة والأمان)
CREATE TABLE roles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(30) UNIQUE NOT NULL,
    permissions JSON
);

CREATE TABLE users (
    id VARCHAR(36) PRIMARY KEY, -- Using VARCHAR(36) to simulate UUID
    phone_number VARCHAR(20) UNIQUE,
    full_name VARCHAR(100) NOT NULL,
    avatar_url TEXT,
    role_id INT,
    district_id INT,
    verification_status ENUM('unverified', 'pending', 'verified', 'rejected') DEFAULT 'unverified',
    trust_score DECIMAL(3,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (role_id) REFERENCES roles(id),
    FOREIGN KEY (district_id) REFERENCES districts(id)
);

CREATE TABLE user_verifications (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36),
    id_front_url TEXT NOT NULL,
    id_back_url TEXT NOT NULL,
    selfie_url TEXT NOT NULL,
    status ENUM('pending', 'approved', 'rejected') DEFAULT 'pending',
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 3. CATEGORIES (الأقسام)
CREATE TABLE categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    parent_id INT,
    name_ar VARCHAR(100) NOT NULL,
    name_en VARCHAR(100) NOT NULL,
    icon_url TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE CASCADE
);

CREATE TABLE category_fields (
    id INT AUTO_INCREMENT PRIMARY KEY,
    category_id INT,
    field_name VARCHAR(50) NOT NULL,
    field_type VARCHAR(20) NOT NULL,
    is_required BOOLEAN DEFAULT FALSE,
    options JSON,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
);

-- 4. ADS & SEARCH (الإعلانات)
CREATE TABLE ads (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36),
    category_id INT,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(12,2),
    currency VARCHAR(10) DEFAULT 'EGP',
    status ENUM('draft', 'pending', 'active', 'sold', 'expired', 'rejected') DEFAULT 'active',
    district_id INT,
    search_attributes JSON, -- Simulated JSON for MySQL
    views_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(id),
    FOREIGN KEY (district_id) REFERENCES districts(id)
);

-- 5. CHAT (الدردشة)
CREATE TABLE conversations (
    id VARCHAR(36) PRIMARY KEY,
    ad_id VARCHAR(36),
    buyer_id VARCHAR(36),
    seller_id VARCHAR(36),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (ad_id) REFERENCES ads(id) ON DELETE CASCADE,
    FOREIGN KEY (buyer_id) REFERENCES users(id),
    FOREIGN KEY (seller_id) REFERENCES users(id)
);

CREATE TABLE messages (
    id VARCHAR(36) PRIMARY KEY,
    conversation_id VARCHAR(36),
    sender_id VARCHAR(36),
    content TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
    FOREIGN KEY (sender_id) REFERENCES users(id)
);

-- 6. SERVICE BOOKINGS (حجوزات العمالة)
CREATE TABLE service_bookings (
    id VARCHAR(36) PRIMARY KEY,
    ad_id VARCHAR(36),
    customer_id VARCHAR(36),
    worker_id VARCHAR(36),
    scheduled_at TIMESTAMP NOT NULL,
    status ENUM('pending', 'accepted', 'in_progress', 'completed', 'cancelled') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (ad_id) REFERENCES ads(id),
    FOREIGN KEY (customer_id) REFERENCES users(id),
    FOREIGN KEY (worker_id) REFERENCES users(id)
);
