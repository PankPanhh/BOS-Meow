/*
===========================================================
Beverage Operating System
01_init.sql
===========================================================
*/

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "citext";

----------------------------------------------------------
-- ENUM
----------------------------------------------------------

CREATE TYPE user_status AS ENUM
(
    'ACTIVE',
    'INACTIVE',
    'LOCKED'
);

CREATE TYPE gender_type AS ENUM
(
    'MALE',
    'FEMALE',
    'OTHER'
);

CREATE TYPE payment_method AS ENUM
(
    'CASH',
    'COD',
    'BANK_TRANSFER',
    'MOMO',
    'ZALOPAY'
);

CREATE TYPE payment_status AS ENUM
(
    'UNPAID',
    'PENDING',
    'PAID',
    'FAILED',
    'REFUNDED'
);

CREATE TYPE order_status AS ENUM
(
    'NEW',
    'CONFIRMED',
    'PREPARING',
    'READY',
    'DELIVERING',
    'COMPLETED',
    'CANCELLED'
);

----------------------------------------------------------
-- BASE FUNCTION
----------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_update_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
BEGIN
    NEW.updated_at = NOW();
    NEW.version = OLD.version + 1;
    RETURN NEW;
END;
$$;

----------------------------------------------------------
-- AUDIT TABLE
----------------------------------------------------------

CREATE TABLE audit_log
(
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    table_name VARCHAR(100) NOT NULL,

    record_id UUID,

    action VARCHAR(20),

    old_data JSONB,

    new_data JSONB,

    created_by UUID,

    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_table
ON audit_log(table_name);

CREATE INDEX idx_audit_record
ON audit_log(record_id);

----------------------------------------------------------
-- SETTING
----------------------------------------------------------

CREATE TABLE app_setting
(
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    setting_key VARCHAR(150) UNIQUE NOT NULL,

    setting_value TEXT,

    description TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    updated_at TIMESTAMPTZ DEFAULT NOW(),

    version INT DEFAULT 1
);

CREATE TRIGGER trg_setting_timestamp
BEFORE UPDATE
ON app_setting
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

/*
===========================================================
AUTH
===========================================================
*/

----------------------------------------------------------
-- ROLE
----------------------------------------------------------

CREATE TABLE role
(
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    code VARCHAR(50) UNIQUE NOT NULL,

    name VARCHAR(100) NOT NULL,

    description TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    updated_at TIMESTAMPTZ DEFAULT NOW(),

    deleted_at TIMESTAMPTZ,

    version INT DEFAULT 1
);

----------------------------------------------------------
-- PERMISSION
----------------------------------------------------------

CREATE TABLE permission
(
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    code VARCHAR(100) UNIQUE NOT NULL,

    module VARCHAR(100),

    action VARCHAR(50),

    description TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    updated_at TIMESTAMPTZ DEFAULT NOW(),

    version INT DEFAULT 1
);

----------------------------------------------------------
-- ROLE PERMISSION
----------------------------------------------------------

CREATE TABLE role_permission
(
    role_id UUID NOT NULL,

    permission_id UUID NOT NULL,

    PRIMARY KEY(role_id,permission_id),

    CONSTRAINT fk_role_permission_role
        FOREIGN KEY(role_id)
        REFERENCES role(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_role_permission_permission
        FOREIGN KEY(permission_id)
        REFERENCES permission(id)
        ON DELETE CASCADE
);

----------------------------------------------------------
-- USER
----------------------------------------------------------

CREATE TABLE app_user
(
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    username VARCHAR(50) UNIQUE NOT NULL,

    email CITEXT UNIQUE,

    phone VARCHAR(20) UNIQUE,

    password_hash TEXT NOT NULL,

    full_name VARCHAR(255),

    avatar TEXT,

    status user_status DEFAULT 'ACTIVE',

    last_login_at TIMESTAMPTZ,

    login_failed_count INT DEFAULT 0,

    email_verified BOOLEAN DEFAULT FALSE,

    phone_verified BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    updated_at TIMESTAMPTZ DEFAULT NOW(),

    deleted_at TIMESTAMPTZ,

    version INT DEFAULT 1
);

----------------------------------------------------------
-- USER ROLE
----------------------------------------------------------

CREATE TABLE user_role
(
    user_id UUID,

    role_id UUID,

    PRIMARY KEY(user_id,role_id),

    FOREIGN KEY(user_id)
        REFERENCES app_user(id)
        ON DELETE CASCADE,

    FOREIGN KEY(role_id)
        REFERENCES role(id)
        ON DELETE CASCADE
);

----------------------------------------------------------
-- REFRESH TOKEN
----------------------------------------------------------

CREATE TABLE refresh_token
(
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL,

    token TEXT NOT NULL,

    expired_at TIMESTAMPTZ NOT NULL,

    revoked BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_refresh_user
        FOREIGN KEY(user_id)
        REFERENCES app_user(id)
);

----------------------------------------------------------
-- LOGIN HISTORY
----------------------------------------------------------

CREATE TABLE login_history
(
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID,

    ip_address VARCHAR(50),

    user_agent TEXT,

    success BOOLEAN,

    login_at TIMESTAMPTZ DEFAULT NOW(),

    FOREIGN KEY(user_id)
        REFERENCES app_user(id)
);

----------------------------------------------------------
-- INDEX
----------------------------------------------------------

CREATE INDEX idx_user_username
ON app_user(username);

CREATE INDEX idx_user_email
ON app_user(email);

CREATE INDEX idx_user_phone
ON app_user(phone);

CREATE INDEX idx_login_user
ON login_history(user_id);

CREATE INDEX idx_refresh_user
ON refresh_token(user_id);

----------------------------------------------------------
-- TRIGGER
----------------------------------------------------------

CREATE TRIGGER trg_role_update
BEFORE UPDATE
ON role
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_permission_update
BEFORE UPDATE
ON permission
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_user_update
BEFORE UPDATE
ON app_user
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

/*
===========================================================
CUSTOMER
===========================================================
*/

----------------------------------------------------------
-- CUSTOMER
----------------------------------------------------------

CREATE TABLE customer
(
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    customer_code VARCHAR(30) UNIQUE NOT NULL,

    full_name VARCHAR(255),

    phone VARCHAR(20) UNIQUE,

    email CITEXT,

    gender gender_type,
`
    birthday DATE,

    avatar TEXT,

    note TEXT,

    total_order INT DEFAULT 0,

    total_spent NUMERIC(18,2) DEFAULT 0,

    loyalty_point INT DEFAULT 0,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    updated_at TIMESTAMPTZ DEFAULT NOW(),

    deleted_at TIMESTAMPTZ,

    version INT DEFAULT 1
);

----------------------------------------------------------
-- CUSTOMER ADDRESS
----------------------------------------------------------

CREATE TABLE customer_address
(
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    customer_id UUID NOT NULL,

    receiver_name VARCHAR(255),

    phone VARCHAR(20),

    province VARCHAR(100),

    district VARCHAR(100),

    ward VARCHAR(100),

    address TEXT,

    latitude NUMERIC(10,7),

    longitude NUMERIC(10,7),

    is_default BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    FOREIGN KEY(customer_id)
        REFERENCES customer(id)
        ON DELETE CASCADE
);

----------------------------------------------------------
-- CUSTOMER FAVORITE
----------------------------------------------------------

CREATE TABLE customer_favorite
(
    customer_id UUID,

    product_id UUID,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    PRIMARY KEY(customer_id,product_id)
);

----------------------------------------------------------
-- CUSTOMER QR
----------------------------------------------------------

CREATE TABLE customer_qr
(
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    customer_id UUID,

    qr_code TEXT,

    expired_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    FOREIGN KEY(customer_id)
        REFERENCES customer(id)
);

----------------------------------------------------------
-- CUSTOMER POINT HISTORY
----------------------------------------------------------

CREATE TABLE customer_point_history
(
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    customer_id UUID,

    point INT,

    description TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    FOREIGN KEY(customer_id)
        REFERENCES customer(id)
);

----------------------------------------------------------
-- INDEX
----------------------------------------------------------

CREATE INDEX idx_customer_phone
ON customer(phone);

CREATE INDEX idx_customer_code
ON customer(customer_code);

CREATE INDEX idx_customer_address_customer
ON customer_address(customer_id);

CREATE INDEX idx_customer_point
ON customer_point_history(customer_id);

----------------------------------------------------------
-- TRIGGER
----------------------------------------------------------

CREATE TRIGGER trg_customer_update
BEFORE UPDATE
ON customer
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

/*
===========================================================
Beverage Operating System
04_product.sql
Part A
Product Catalog
===========================================================
*/

------------------------------------------------------------
-- PRODUCT CATEGORY
------------------------------------------------------------

CREATE TABLE product_category
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    parent_id           UUID,

    category_code       VARCHAR(50) NOT NULL UNIQUE,

    category_name       VARCHAR(255) NOT NULL,

    slug                VARCHAR(255) UNIQUE,

    image_url           TEXT,

    description         TEXT,

    display_order       INT DEFAULT 0,

    is_active           BOOLEAN DEFAULT TRUE,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    updated_at          TIMESTAMPTZ DEFAULT NOW(),

    deleted_at          TIMESTAMPTZ,

    version             INT DEFAULT 1,

    CONSTRAINT fk_product_category_parent
        FOREIGN KEY(parent_id)
        REFERENCES product_category(id)
);

CREATE INDEX idx_product_category_parent
ON product_category(parent_id);

CREATE INDEX idx_product_category_name
ON product_category(category_name);

------------------------------------------------------------
-- PRODUCT TAG
------------------------------------------------------------

CREATE TABLE tag
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    tag_code            VARCHAR(50) UNIQUE NOT NULL,

    tag_name            VARCHAR(100) NOT NULL,

    color               VARCHAR(20),

    icon                VARCHAR(100),

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    updated_at          TIMESTAMPTZ DEFAULT NOW(),

    version             INT DEFAULT 1
);

------------------------------------------------------------
-- PRODUCT
------------------------------------------------------------

CREATE TABLE product
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    category_id             UUID NOT NULL,

    product_code            VARCHAR(50) UNIQUE NOT NULL,

    product_name            VARCHAR(255) NOT NULL,

    slug                    VARCHAR(255) UNIQUE,

    short_description       TEXT,

    description             TEXT,

    thumbnail               TEXT,

    qr_code                 TEXT,

    barcode                 VARCHAR(100),

    seo_title               VARCHAR(255),

    seo_keyword             TEXT,

    seo_description         TEXT,

    is_active               BOOLEAN DEFAULT TRUE,

    is_featured             BOOLEAN DEFAULT FALSE,

    allow_note              BOOLEAN DEFAULT TRUE,

    display_order           INT DEFAULT 0,

    created_at              TIMESTAMPTZ DEFAULT NOW(),

    updated_at              TIMESTAMPTZ DEFAULT NOW(),

    deleted_at              TIMESTAMPTZ,

    version                 INT DEFAULT 1,

    CONSTRAINT fk_product_category
        FOREIGN KEY(category_id)
        REFERENCES product_category(id)
);

CREATE INDEX idx_product_category
ON product(category_id);

CREATE INDEX idx_product_name
ON product(product_name);

CREATE INDEX idx_product_slug
ON product(slug);

------------------------------------------------------------
-- PRODUCT IMAGE
------------------------------------------------------------

CREATE TABLE product_image
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    product_id          UUID NOT NULL,

    image_url           TEXT NOT NULL,

    is_thumbnail        BOOLEAN DEFAULT FALSE,

    display_order       INT DEFAULT 0,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_product_image_product
        FOREIGN KEY(product_id)
        REFERENCES product(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_product_image_product
ON product_image(product_id);

------------------------------------------------------------
-- PRODUCT TAG MAPPING
------------------------------------------------------------

CREATE TABLE product_tag
(
    product_id      UUID,

    tag_id          UUID,

    created_at      TIMESTAMPTZ DEFAULT NOW(),

    PRIMARY KEY(product_id,tag_id),

    CONSTRAINT fk_product_tag_product
        FOREIGN KEY(product_id)
        REFERENCES product(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_product_tag_tag
        FOREIGN KEY(tag_id)
        REFERENCES tag(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- PRODUCT SIZE
------------------------------------------------------------

CREATE TABLE product_size
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    size_code           VARCHAR(20) UNIQUE NOT NULL,

    size_name           VARCHAR(50) NOT NULL,

    display_order       INT DEFAULT 0,

    is_active           BOOLEAN DEFAULT TRUE,

    created_at          TIMESTAMPTZ DEFAULT NOW()
);

------------------------------------------------------------
-- PRODUCT VARIANT
------------------------------------------------------------

CREATE TABLE product_variant
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    product_id              UUID NOT NULL,

    size_id                 UUID NOT NULL,

    sku                     VARCHAR(100) UNIQUE,

    barcode                 VARCHAR(100),

    selling_price           NUMERIC(18,2) NOT NULL,

    compare_price           NUMERIC(18,2),

    is_default              BOOLEAN DEFAULT FALSE,

    is_active               BOOLEAN DEFAULT TRUE,

    created_at              TIMESTAMPTZ DEFAULT NOW(),

    updated_at              TIMESTAMPTZ DEFAULT NOW(),

    version                 INT DEFAULT 1,

    CONSTRAINT fk_variant_product
        FOREIGN KEY(product_id)
        REFERENCES product(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_variant_size
        FOREIGN KEY(size_id)
        REFERENCES product_size(id),

    CONSTRAINT uq_product_size
        UNIQUE(product_id,size_id)
);

CREATE INDEX idx_variant_product
ON product_variant(product_id);

CREATE INDEX idx_variant_size
ON product_variant(size_id);

CREATE INDEX idx_variant_price
ON product_variant(selling_price);

------------------------------------------------------------
-- PRICE HISTORY
------------------------------------------------------------

CREATE TABLE product_price_history
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    variant_id          UUID NOT NULL,

    old_price           NUMERIC(18,2),

    new_price           NUMERIC(18,2),

    effective_from      TIMESTAMPTZ DEFAULT NOW(),

    effective_to        TIMESTAMPTZ,

    changed_by          UUID,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_price_variant
        FOREIGN KEY(variant_id)
        REFERENCES product_variant(id)
);

CREATE INDEX idx_price_history_variant
ON product_price_history(variant_id);

------------------------------------------------------------
-- UPDATE TRIGGER
------------------------------------------------------------

CREATE TRIGGER trg_product_category_update
BEFORE UPDATE
ON product_category
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_product_update
BEFORE UPDATE
ON product
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_variant_update
BEFORE UPDATE
ON product_variant
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

/*
===========================================================
Beverage Operating System
04_product.sql
Part B
Modifier - Topping - Combo - Menu
===========================================================
*/

------------------------------------------------------------
-- MODIFIER GROUP
------------------------------------------------------------

CREATE TABLE modifier_group
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    group_code          VARCHAR(50) UNIQUE NOT NULL,

    group_name          VARCHAR(150) NOT NULL,

    description         TEXT,

    min_select          INT DEFAULT 0,

    max_select          INT DEFAULT 1,

    is_required         BOOLEAN DEFAULT FALSE,

    display_order       INT DEFAULT 0,

    is_active           BOOLEAN DEFAULT TRUE,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    updated_at          TIMESTAMPTZ DEFAULT NOW(),

    version             INT DEFAULT 1
);

CREATE INDEX idx_modifier_group_name
ON modifier_group(group_name);

------------------------------------------------------------
-- MODIFIER OPTION
------------------------------------------------------------

CREATE TABLE modifier_option
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    group_id            UUID NOT NULL,

    option_code         VARCHAR(50) UNIQUE NOT NULL,

    option_name         VARCHAR(150) NOT NULL,

    extra_price         NUMERIC(18,2) DEFAULT 0,

    display_order       INT DEFAULT 0,

    is_default          BOOLEAN DEFAULT FALSE,

    is_active           BOOLEAN DEFAULT TRUE,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    updated_at          TIMESTAMPTZ DEFAULT NOW(),

    version             INT DEFAULT 1,

    CONSTRAINT fk_modifier_option_group
        FOREIGN KEY(group_id)
        REFERENCES modifier_group(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_modifier_option_group
ON modifier_option(group_id);

------------------------------------------------------------
-- PRODUCT MODIFIER GROUP
------------------------------------------------------------

CREATE TABLE product_modifier_group
(
    product_id          UUID,

    modifier_group_id   UUID,

    PRIMARY KEY(product_id, modifier_group_id),

    CONSTRAINT fk_pmg_product
        FOREIGN KEY(product_id)
        REFERENCES product(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_pmg_group
        FOREIGN KEY(modifier_group_id)
        REFERENCES modifier_group(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- TOPPING CATEGORY
------------------------------------------------------------

CREATE TABLE topping_category
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    category_code       VARCHAR(50) UNIQUE NOT NULL,

    category_name       VARCHAR(150) NOT NULL,

    display_order       INT DEFAULT 0,

    is_active           BOOLEAN DEFAULT TRUE,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    updated_at          TIMESTAMPTZ DEFAULT NOW(),

    version             INT DEFAULT 1
);

------------------------------------------------------------
-- TOPPING
------------------------------------------------------------

CREATE TABLE topping
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    category_id         UUID NOT NULL,

    topping_code        VARCHAR(50) UNIQUE NOT NULL,

    topping_name        VARCHAR(150) NOT NULL,

    selling_price       NUMERIC(18,2) DEFAULT 0,

    image_url           TEXT,

    display_order       INT DEFAULT 0,

    is_active           BOOLEAN DEFAULT TRUE,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    updated_at          TIMESTAMPTZ DEFAULT NOW(),

    version             INT DEFAULT 1,

    CONSTRAINT fk_topping_category
        FOREIGN KEY(category_id)
        REFERENCES topping_category(id)
);

CREATE INDEX idx_topping_category
ON topping(category_id);

------------------------------------------------------------
-- PRODUCT VARIANT TOPPING
------------------------------------------------------------

CREATE TABLE product_variant_topping
(
    variant_id          UUID,

    topping_id          UUID,

    is_default          BOOLEAN DEFAULT FALSE,

    max_quantity        INT DEFAULT 1,

    PRIMARY KEY(variant_id, topping_id),

    CONSTRAINT fk_variant_topping_variant
        FOREIGN KEY(variant_id)
        REFERENCES product_variant(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_variant_topping_topping
        FOREIGN KEY(topping_id)
        REFERENCES topping(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- COMBO
------------------------------------------------------------

CREATE TABLE combo
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    combo_code          VARCHAR(50) UNIQUE NOT NULL,

    combo_name          VARCHAR(255) NOT NULL,

    description         TEXT,

    selling_price       NUMERIC(18,2) NOT NULL,

    image_url           TEXT,

    start_date          DATE,

    end_date            DATE,

    is_active           BOOLEAN DEFAULT TRUE,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    updated_at          TIMESTAMPTZ DEFAULT NOW(),

    version             INT DEFAULT 1
);

------------------------------------------------------------
-- COMBO ITEM
------------------------------------------------------------

CREATE TABLE combo_item
(
    combo_id            UUID,

    variant_id          UUID,

    quantity            NUMERIC(10,2) DEFAULT 1,

    PRIMARY KEY(combo_id, variant_id),

    CONSTRAINT fk_combo_item_combo
        FOREIGN KEY(combo_id)
        REFERENCES combo(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_combo_item_variant
        FOREIGN KEY(variant_id)
        REFERENCES product_variant(id)
);

------------------------------------------------------------
-- MENU
------------------------------------------------------------

CREATE TABLE menu
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    menu_code           VARCHAR(50) UNIQUE NOT NULL,

    menu_name           VARCHAR(150) NOT NULL,

    description         TEXT,

    start_time          TIME,

    end_time            TIME,

    is_default          BOOLEAN DEFAULT FALSE,

    is_active           BOOLEAN DEFAULT TRUE,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    updated_at          TIMESTAMPTZ DEFAULT NOW(),

    version             INT DEFAULT 1
);

------------------------------------------------------------
-- MENU CATEGORY
------------------------------------------------------------

CREATE TABLE menu_category
(
    menu_id             UUID,

    category_id         UUID,

    display_order       INT DEFAULT 0,

    PRIMARY KEY(menu_id, category_id),

    CONSTRAINT fk_menu_category_menu
        FOREIGN KEY(menu_id)
        REFERENCES menu(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_menu_category_product_category
        FOREIGN KEY(category_id)
        REFERENCES product_category(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- MENU PRODUCT
------------------------------------------------------------

CREATE TABLE menu_product
(
    menu_id             UUID,

    variant_id          UUID,

    display_order       INT DEFAULT 0,

    PRIMARY KEY(menu_id, variant_id),

    CONSTRAINT fk_menu_product_menu
        FOREIGN KEY(menu_id)
        REFERENCES menu(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_menu_product_variant
        FOREIGN KEY(variant_id)
        REFERENCES product_variant(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- PRODUCT AVAILABILITY
------------------------------------------------------------

CREATE TABLE product_availability
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    variant_id          UUID NOT NULL,

    day_of_week         SMALLINT NOT NULL CHECK(day_of_week BETWEEN 0 AND 6),

    start_time          TIME NOT NULL,

    end_time            TIME NOT NULL,

    is_available        BOOLEAN DEFAULT TRUE,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_product_availability_variant
        FOREIGN KEY(variant_id)
        REFERENCES product_variant(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_product_availability_variant
ON product_availability(variant_id);

------------------------------------------------------------
-- UPDATE TRIGGER
------------------------------------------------------------

CREATE TRIGGER trg_modifier_group_update
BEFORE UPDATE
ON modifier_group
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_modifier_option_update
BEFORE UPDATE
ON modifier_option
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_topping_category_update
BEFORE UPDATE
ON topping_category
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_topping_update
BEFORE UPDATE
ON topping
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_combo_update
BEFORE UPDATE
ON combo
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_menu_update
BEFORE UPDATE
ON menu
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

/*
===========================================================
Beverage Operating System
04_product.sql
Part C
Enterprise Extension
===========================================================
*/

------------------------------------------------------------
-- ATTRIBUTE
------------------------------------------------------------

CREATE TABLE product_attribute
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    attribute_code      VARCHAR(50) UNIQUE NOT NULL,

    attribute_name      VARCHAR(100) NOT NULL,

    description         TEXT,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    updated_at          TIMESTAMPTZ DEFAULT NOW(),

    version             INT DEFAULT 1
);

------------------------------------------------------------
-- ATTRIBUTE VALUE
------------------------------------------------------------

CREATE TABLE product_attribute_value
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    attribute_id        UUID NOT NULL,

    value_name          VARCHAR(100) NOT NULL,

    display_order       INT DEFAULT 0,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_attribute_value
        FOREIGN KEY(attribute_id)
        REFERENCES product_attribute(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- PRODUCT ATTRIBUTE
------------------------------------------------------------

CREATE TABLE product_variant_attribute
(
    variant_id          UUID,

    attribute_value_id  UUID,

    PRIMARY KEY
    (
        variant_id,
        attribute_value_id
    ),

    CONSTRAINT fk_pva_variant
        FOREIGN KEY(variant_id)
        REFERENCES product_variant(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_pva_attribute
        FOREIGN KEY(attribute_value_id)
        REFERENCES product_attribute_value(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- PRICE LIST
------------------------------------------------------------

CREATE TABLE price_list
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    price_code          VARCHAR(50) UNIQUE NOT NULL,

    price_name          VARCHAR(150) NOT NULL,

    description         TEXT,

    is_default          BOOLEAN DEFAULT FALSE,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    updated_at          TIMESTAMPTZ DEFAULT NOW(),

    version             INT DEFAULT 1
);

------------------------------------------------------------
-- PRICE LIST ITEM
------------------------------------------------------------

CREATE TABLE price_list_item
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    price_list_id       UUID NOT NULL,

    variant_id          UUID NOT NULL,

    selling_price       NUMERIC(18,2) NOT NULL,

    start_date          TIMESTAMPTZ,

    end_date            TIMESTAMPTZ,

    CONSTRAINT fk_price_list
        FOREIGN KEY(price_list_id)
        REFERENCES price_list(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_price_variant
        FOREIGN KEY(variant_id)
        REFERENCES product_variant(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_price_list_item_variant
ON price_list_item(variant_id);

------------------------------------------------------------
-- DISPLAY CHANNEL
------------------------------------------------------------

CREATE TABLE display_channel
(
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    channel_code    VARCHAR(50) UNIQUE NOT NULL,

    channel_name    VARCHAR(100) NOT NULL
);

------------------------------------------------------------
-- PRODUCT CHANNEL
------------------------------------------------------------

CREATE TABLE product_channel
(
    variant_id      UUID,

    channel_id      UUID,

    PRIMARY KEY
    (
        variant_id,
        channel_id
    ),

    FOREIGN KEY(variant_id)
        REFERENCES product_variant(id)
        ON DELETE CASCADE,

    FOREIGN KEY(channel_id)
        REFERENCES display_channel(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- PRODUCT RECOMMENDATION
------------------------------------------------------------

CREATE TABLE product_recommendation
(
    product_id              UUID,

    recommend_product_id    UUID,

    priority                INT DEFAULT 1,

    PRIMARY KEY
    (
        product_id,
        recommend_product_id
    ),

    FOREIGN KEY(product_id)
        REFERENCES product(id)
        ON DELETE CASCADE,

    FOREIGN KEY(recommend_product_id)
        REFERENCES product(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- PRODUCT SEO
------------------------------------------------------------

CREATE TABLE product_seo
(
    product_id          UUID PRIMARY KEY,

    canonical_url       TEXT,

    meta_title          VARCHAR(255),

    meta_keyword        TEXT,

    meta_description    TEXT,

    open_graph_image    TEXT,

    FOREIGN KEY(product_id)
        REFERENCES product(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- PRODUCT STATUS HISTORY
------------------------------------------------------------

CREATE TABLE product_status_history
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    product_id          UUID,

    old_status          BOOLEAN,

    new_status          BOOLEAN,

    changed_by          UUID,

    changed_at          TIMESTAMPTZ DEFAULT NOW(),

    FOREIGN KEY(product_id)
        REFERENCES product(id)
);

------------------------------------------------------------
-- INDEX
------------------------------------------------------------

CREATE INDEX idx_product_recommendation
ON product_recommendation(product_id);

CREATE INDEX idx_product_channel
ON product_channel(variant_id);

------------------------------------------------------------
-- TRIGGER
------------------------------------------------------------

CREATE TRIGGER trg_attribute_update
BEFORE UPDATE
ON product_attribute
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_price_list_update
BEFORE UPDATE
ON price_list
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

------------------------------------------------------------
-- DEFAULT DATA
------------------------------------------------------------

INSERT INTO display_channel
(channel_code, channel_name)
VALUES
('WEBSITE','Website'),
('POS','POS'),
('QR','QR Ordering'),
('MOBILE','Mobile App')
ON CONFLICT DO NOTHING;

INSERT INTO price_list
(price_code,price_name,is_default)
VALUES
('DEFAULT','Default Price',TRUE),
('PROMOTION','Promotion',FALSE),
('MEMBER','Member',FALSE)
ON CONFLICT DO NOTHING;

/*
===========================================================
Beverage Operating System
05_recipe.sql
Part A
Recipe Core
===========================================================
*/

------------------------------------------------------------
-- RECIPE
------------------------------------------------------------

CREATE TABLE recipe
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    recipe_code             VARCHAR(50) UNIQUE NOT NULL,

    recipe_name             VARCHAR(255) NOT NULL,

    product_variant_id      UUID NOT NULL,

    description             TEXT,

    is_active               BOOLEAN DEFAULT TRUE,

    created_at              TIMESTAMPTZ DEFAULT NOW(),

    updated_at              TIMESTAMPTZ DEFAULT NOW(),

    deleted_at              TIMESTAMPTZ,

    version                 INT DEFAULT 1,

    CONSTRAINT fk_recipe_variant
        FOREIGN KEY(product_variant_id)
        REFERENCES product_variant(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_recipe_variant
ON recipe(product_variant_id);

------------------------------------------------------------
-- RECIPE VERSION
------------------------------------------------------------

CREATE TABLE recipe_version
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    recipe_id               UUID NOT NULL,

    version_no              INT NOT NULL,

    version_name            VARCHAR(100),

    note                    TEXT,

    effective_from          TIMESTAMPTZ DEFAULT NOW(),

    effective_to            TIMESTAMPTZ,

    is_current              BOOLEAN DEFAULT FALSE,

    approved_by             UUID,

    approved_at             TIMESTAMPTZ,

    created_by              UUID,

    created_at              TIMESTAMPTZ DEFAULT NOW(),

    updated_at              TIMESTAMPTZ DEFAULT NOW(),

    version                 INT DEFAULT 1,

    CONSTRAINT fk_recipe_version_recipe
        FOREIGN KEY(recipe_id)
        REFERENCES recipe(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_recipe_version_approved
        FOREIGN KEY(approved_by)
        REFERENCES app_user(id),

    CONSTRAINT fk_recipe_version_created
        FOREIGN KEY(created_by)
        REFERENCES app_user(id),

    CONSTRAINT uq_recipe_version
        UNIQUE(recipe_id, version_no)
);

CREATE INDEX idx_recipe_version_recipe
ON recipe_version(recipe_id);

CREATE INDEX idx_recipe_version_current
ON recipe_version(is_current);

------------------------------------------------------------
-- RECIPE STEP
------------------------------------------------------------

CREATE TABLE recipe_step
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    recipe_version_id       UUID NOT NULL,

    step_no                 INT NOT NULL,

    step_name               VARCHAR(255),

    instruction             TEXT NOT NULL,

    estimated_second        INT DEFAULT 0,

    created_at              TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_recipe_step
        FOREIGN KEY(recipe_version_id)
        REFERENCES recipe_version(id)
        ON DELETE CASCADE,

    CONSTRAINT uq_recipe_step
        UNIQUE(recipe_version_id, step_no)
);

CREATE INDEX idx_recipe_step_recipe
ON recipe_step(recipe_version_id);

------------------------------------------------------------
-- UNIT
------------------------------------------------------------

CREATE TABLE ingredient_unit
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    unit_code           VARCHAR(20) UNIQUE NOT NULL,

    unit_name           VARCHAR(100) NOT NULL,

    symbol              VARCHAR(20),

    decimal_place       SMALLINT DEFAULT 2,

    is_active           BOOLEAN DEFAULT TRUE,

    created_at          TIMESTAMPTZ DEFAULT NOW()
);

------------------------------------------------------------
-- RECIPE INGREDIENT
------------------------------------------------------------

CREATE TABLE recipe_ingredient
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    recipe_version_id       UUID NOT NULL,

    ingredient_id           UUID NOT NULL,

    unit_id                 UUID NOT NULL,

    quantity                NUMERIC(18,4) NOT NULL,

    wastage_percent         NUMERIC(5,2) DEFAULT 0,

    display_order           INT DEFAULT 0,

    note                    TEXT,

    created_at              TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_recipe_ingredient_recipe
        FOREIGN KEY(recipe_version_id)
        REFERENCES recipe_version(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_recipe_ingredient_unit
        FOREIGN KEY(unit_id)
        REFERENCES ingredient_unit(id)
);

CREATE INDEX idx_recipe_ingredient_recipe
ON recipe_ingredient(recipe_version_id);

------------------------------------------------------------
-- RECIPE EQUIPMENT
------------------------------------------------------------

CREATE TABLE recipe_equipment
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    recipe_version_id       UUID NOT NULL,

    equipment_name          VARCHAR(255),

    quantity                NUMERIC(10,2) DEFAULT 1,

    created_at              TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_recipe_equipment
        FOREIGN KEY(recipe_version_id)
        REFERENCES recipe_version(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- RECIPE NOTE
------------------------------------------------------------

CREATE TABLE recipe_note
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    recipe_version_id       UUID NOT NULL,

    note_type               VARCHAR(50),

    note_content            TEXT,

    created_by              UUID,

    created_at              TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_recipe_note_recipe
        FOREIGN KEY(recipe_version_id)
        REFERENCES recipe_version(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_recipe_note_user
        FOREIGN KEY(created_by)
        REFERENCES app_user(id)
);

------------------------------------------------------------
-- TRIGGER
------------------------------------------------------------

CREATE TRIGGER trg_recipe_update
BEFORE UPDATE
ON recipe
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_recipe_version_update
BEFORE UPDATE
ON recipe_version
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

------------------------------------------------------------
-- DEFAULT UNIT
------------------------------------------------------------

INSERT INTO ingredient_unit
(unit_code, unit_name, symbol)
VALUES
('G','Gram','g'),
('KG','Kilogram','kg'),
('ML','Milliliter','ml'),
('L','Liter','L'),
('PCS','Piece','pcs'),
('PACK','Pack','pack'),
('BOTTLE','Bottle','bottle'),
('CUP','Cup','cup')
ON CONFLICT DO NOTHING;

/*
===========================================================
Beverage Operating System
05_recipe.sql
Part B
Ingredient & Cost Engine
===========================================================
*/

------------------------------------------------------------
-- INGREDIENT CATEGORY
------------------------------------------------------------

CREATE TABLE ingredient_category
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    category_code       VARCHAR(50) UNIQUE NOT NULL,

    category_name       VARCHAR(150) NOT NULL,

    description         TEXT,

    display_order       INT DEFAULT 0,

    is_active           BOOLEAN DEFAULT TRUE,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    updated_at          TIMESTAMPTZ DEFAULT NOW(),

    version             INT DEFAULT 1
);

CREATE INDEX idx_ingredient_category_name
ON ingredient_category(category_name);

------------------------------------------------------------
-- INGREDIENT
------------------------------------------------------------

CREATE TABLE ingredient
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    category_id             UUID NOT NULL,

    ingredient_code         VARCHAR(50) UNIQUE NOT NULL,

    ingredient_name         VARCHAR(255) NOT NULL,

    unit_id                 UUID NOT NULL,

    description             TEXT,

    barcode                 VARCHAR(100),

    minimum_stock           NUMERIC(18,4) DEFAULT 0,

    maximum_stock           NUMERIC(18,4),

    reorder_point           NUMERIC(18,4) DEFAULT 0,

    shelf_life_day          INT,

    is_inventory            BOOLEAN DEFAULT TRUE,

    is_active               BOOLEAN DEFAULT TRUE,

    created_at              TIMESTAMPTZ DEFAULT NOW(),

    updated_at              TIMESTAMPTZ DEFAULT NOW(),

    deleted_at              TIMESTAMPTZ,

    version                 INT DEFAULT 1,

    CONSTRAINT fk_ingredient_category
        FOREIGN KEY(category_id)
        REFERENCES ingredient_category(id),

    CONSTRAINT fk_ingredient_unit
        FOREIGN KEY(unit_id)
        REFERENCES ingredient_unit(id)
);

CREATE INDEX idx_ingredient_code
ON ingredient(ingredient_code);

CREATE INDEX idx_ingredient_name
ON ingredient(ingredient_name);

------------------------------------------------------------
-- INGREDIENT SUPPLIER
------------------------------------------------------------

CREATE TABLE ingredient_supplier
(
    ingredient_id       UUID,

    supplier_id         UUID,

    priority            INT DEFAULT 1,

    is_default          BOOLEAN DEFAULT FALSE,

    PRIMARY KEY
    (
        ingredient_id,
        supplier_id
    ),

    FOREIGN KEY(ingredient_id)
        REFERENCES ingredient(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- INGREDIENT PRICE HISTORY
------------------------------------------------------------

CREATE TABLE ingredient_price_history
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    ingredient_id           UUID NOT NULL,

    supplier_id             UUID,

    unit_price              NUMERIC(18,4) NOT NULL,

    effective_from          TIMESTAMPTZ DEFAULT NOW(),

    effective_to            TIMESTAMPTZ,

    note                    TEXT,

    created_at              TIMESTAMPTZ DEFAULT NOW(),

    FOREIGN KEY(ingredient_id)
        REFERENCES ingredient(id)
);

CREATE INDEX idx_price_history_ingredient
ON ingredient_price_history(ingredient_id);

------------------------------------------------------------
-- RECIPE COST
------------------------------------------------------------

CREATE TABLE recipe_cost
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    recipe_version_id       UUID UNIQUE NOT NULL,

    ingredient_cost         NUMERIC(18,4) DEFAULT 0,

    packaging_cost          NUMERIC(18,4) DEFAULT 0,

    labor_cost              NUMERIC(18,4) DEFAULT 0,

    overhead_cost           NUMERIC(18,4) DEFAULT 0,

    total_cost              NUMERIC(18,4) DEFAULT 0,

    calculated_at           TIMESTAMPTZ DEFAULT NOW(),

    FOREIGN KEY(recipe_version_id)
        REFERENCES recipe_version(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- RECIPE COST DETAIL
------------------------------------------------------------

CREATE TABLE recipe_cost_detail
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    recipe_cost_id          UUID NOT NULL,

    ingredient_id           UUID NOT NULL,

    quantity                NUMERIC(18,4),

    unit_cost               NUMERIC(18,4),

    total_cost              NUMERIC(18,4),

    FOREIGN KEY(recipe_cost_id)
        REFERENCES recipe_cost(id)
        ON DELETE CASCADE,

    FOREIGN KEY(ingredient_id)
        REFERENCES ingredient(id)
);

CREATE INDEX idx_recipe_cost_detail
ON recipe_cost_detail(recipe_cost_id);

------------------------------------------------------------
-- RECIPE YIELD
------------------------------------------------------------

CREATE TABLE recipe_yield
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    recipe_version_id       UUID UNIQUE NOT NULL,

    yield_quantity          NUMERIC(18,4),

    yield_unit              VARCHAR(50),

    serving                 NUMERIC(18,4),

    FOREIGN KEY(recipe_version_id)
        REFERENCES recipe_version(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- RECIPE NUTRITION
------------------------------------------------------------

CREATE TABLE recipe_nutrition
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    recipe_version_id       UUID UNIQUE NOT NULL,

    calories                NUMERIC(10,2),

    carbohydrate            NUMERIC(10,2),

    protein                 NUMERIC(10,2),

    fat                     NUMERIC(10,2),

    sugar                   NUMERIC(10,2),

    sodium                  NUMERIC(10,2),

    FOREIGN KEY(recipe_version_id)
        REFERENCES recipe_version(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- ALLERGEN
------------------------------------------------------------

CREATE TABLE allergen
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    allergen_code       VARCHAR(50) UNIQUE,

    allergen_name       VARCHAR(150)
);

------------------------------------------------------------
-- RECIPE ALLERGEN
------------------------------------------------------------

CREATE TABLE recipe_allergen
(
    recipe_version_id   UUID,

    allergen_id         UUID,

    PRIMARY KEY
    (
        recipe_version_id,
        allergen_id
    ),

    FOREIGN KEY(recipe_version_id)
        REFERENCES recipe_version(id)
        ON DELETE CASCADE,

    FOREIGN KEY(allergen_id)
        REFERENCES allergen(id)
);

------------------------------------------------------------
-- COST CALCULATION FUNCTION
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_calculate_recipe_cost
(
    p_recipe_version UUID
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS
$$
DECLARE

    v_total NUMERIC(18,4);

BEGIN

    SELECT
        COALESCE
        (
            SUM
            (
                ri.quantity *
                COALESCE
                (
                    (
                        SELECT unit_price
                        FROM ingredient_price_history iph
                        WHERE iph.ingredient_id = ri.ingredient_id
                        ORDER BY effective_from DESC
                        LIMIT 1
                    ),
                    0
                )
            ),
            0
        )
    INTO v_total
    FROM recipe_ingredient ri
    WHERE ri.recipe_version_id = p_recipe_version;

    RETURN v_total;

END;
$$;

------------------------------------------------------------
-- UPDATE TRIGGER
------------------------------------------------------------

CREATE TRIGGER trg_ingredient_category_update
BEFORE UPDATE
ON ingredient_category
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_ingredient_update
BEFORE UPDATE
ON ingredient
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

/*
===========================================================
Beverage Operating System
06_inventory.sql
Inventory Management (Warehouse / Batch - FEFO / Stock Ledger)
===========================================================
*/

------------------------------------------------------------
-- ENUM
------------------------------------------------------------

CREATE TYPE movement_type AS ENUM
(
    'IMPORT',
    'EXPORT',
    'ADJUST_INCREASE',
    'ADJUST_DECREASE',
    'TRANSFER_IN',
    'TRANSFER_OUT',
    'WASTE',
    'ORDER_CONSUME',
    'ORDER_RETURN'
);

CREATE TYPE adjustment_type AS ENUM
(
    'INCREASE',
    'DECREASE'
);

CREATE TYPE transfer_status AS ENUM
(
    'DRAFT',
    'IN_TRANSIT',
    'COMPLETED',
    'CANCELLED'
);

------------------------------------------------------------
-- WAREHOUSE
------------------------------------------------------------

CREATE TABLE warehouse
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    warehouse_code           VARCHAR(50) UNIQUE NOT NULL,

    warehouse_name           VARCHAR(255) NOT NULL,

    address                  TEXT,

    is_default                BOOLEAN DEFAULT FALSE,

    is_active                 BOOLEAN DEFAULT TRUE,

    created_at                TIMESTAMPTZ DEFAULT NOW(),

    updated_at                TIMESTAMPTZ DEFAULT NOW(),

    version                   INT DEFAULT 1
);

CREATE INDEX idx_warehouse_code
ON warehouse(warehouse_code);

------------------------------------------------------------
-- INVENTORY BATCH
-- Nguyên liệu không lưu theo tổng số lượng mà lưu theo lô nhập
-- (ngày nhập / HSD / giá nhập) để tính giá vốn và FEFO chính xác
------------------------------------------------------------

CREATE TABLE inventory_batch
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    ingredient_id            UUID NOT NULL,

    warehouse_id              UUID NOT NULL,

    batch_code                 VARCHAR(50) UNIQUE NOT NULL,

    supplier_id                 UUID,

    purchase_item_id            UUID,

    quantity                     NUMERIC(18,4) NOT NULL,

    remain_quantity               NUMERIC(18,4) NOT NULL,

    import_price                   NUMERIC(18,4) NOT NULL DEFAULT 0,

    imported_at                     TIMESTAMPTZ DEFAULT NOW(),

    expired_at                       TIMESTAMPTZ,

    note                               TEXT,

    created_at                          TIMESTAMPTZ DEFAULT NOW(),

    updated_at                           TIMESTAMPTZ DEFAULT NOW(),

    version                               INT DEFAULT 1,

    CONSTRAINT fk_inventory_batch_ingredient
        FOREIGN KEY(ingredient_id)
        REFERENCES ingredient(id),

    CONSTRAINT fk_inventory_batch_warehouse
        FOREIGN KEY(warehouse_id)
        REFERENCES warehouse(id),

    CONSTRAINT ck_inventory_batch_remain
        CHECK(remain_quantity >= 0 AND remain_quantity <= quantity)
);

-- supplier_id / purchase_item_id được ràng buộc FK ở 07_purchase.sql
-- (supplier & purchase_item chưa tồn tại tại thời điểm chạy file này)

CREATE INDEX idx_inventory_batch_ingredient
ON inventory_batch(ingredient_id);

CREATE INDEX idx_inventory_batch_warehouse
ON inventory_batch(warehouse_id);

CREATE INDEX idx_inventory_batch_expired
ON inventory_batch(expired_at);

CREATE INDEX idx_inventory_batch_remain
ON inventory_batch(remain_quantity);

------------------------------------------------------------
-- INVENTORY STOCK
-- Bảng tổng hợp tồn kho hiện tại theo nguyên liệu / kho
-- (cache tổng hợp từ inventory_batch, phục vụ đọc nhanh
-- cho Dashboard, Recipe availability, Order checkout)
------------------------------------------------------------

CREATE TABLE inventory_stock
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    ingredient_id            UUID NOT NULL,

    warehouse_id               UUID NOT NULL,

    quantity_on_hand             NUMERIC(18,4) NOT NULL DEFAULT 0,

    reserved_quantity              NUMERIC(18,4) NOT NULL DEFAULT 0,

    updated_at                       TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_inventory_stock_ingredient
        FOREIGN KEY(ingredient_id)
        REFERENCES ingredient(id),

    CONSTRAINT fk_inventory_stock_warehouse
        FOREIGN KEY(warehouse_id)
        REFERENCES warehouse(id),

    CONSTRAINT uq_inventory_stock
        UNIQUE(ingredient_id, warehouse_id)
);

CREATE INDEX idx_inventory_stock_ingredient
ON inventory_stock(ingredient_id);

CREATE INDEX idx_inventory_stock_warehouse
ON inventory_stock(warehouse_id);

------------------------------------------------------------
-- STOCK MOVEMENT (SỔ CÁI KHO / LEDGER)
-- Mọi biến động kho đều phải đi qua bảng này -> Single Source
-- of Truth cho toàn bộ Cost Engine & Report
------------------------------------------------------------

CREATE TABLE stock_movement
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    ingredient_id            UUID NOT NULL,

    warehouse_id               UUID NOT NULL,

    batch_id                     UUID,

    movement_type                  movement_type NOT NULL,

    quantity                         NUMERIC(18,4) NOT NULL,

    unit_cost                          NUMERIC(18,4) DEFAULT 0,

    reference_type                       VARCHAR(50),

    reference_id                           UUID,

    note                                     TEXT,

    created_by                                UUID,

    created_at                                 TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_stock_movement_ingredient
        FOREIGN KEY(ingredient_id)
        REFERENCES ingredient(id),

    CONSTRAINT fk_stock_movement_warehouse
        FOREIGN KEY(warehouse_id)
        REFERENCES warehouse(id),

    CONSTRAINT fk_stock_movement_batch
        FOREIGN KEY(batch_id)
        REFERENCES inventory_batch(id),

    CONSTRAINT fk_stock_movement_user
        FOREIGN KEY(created_by)
        REFERENCES app_user(id)
);

CREATE INDEX idx_stock_movement_ingredient
ON stock_movement(ingredient_id);

CREATE INDEX idx_stock_movement_warehouse
ON stock_movement(warehouse_id);

CREATE INDEX idx_stock_movement_reference
ON stock_movement(reference_type, reference_id);

CREATE INDEX idx_stock_movement_created
ON stock_movement(created_at);

------------------------------------------------------------
-- STOCK ADJUSTMENT (KIỂM KHO / ĐIỀU CHỈNH THỦ CÔNG)
------------------------------------------------------------

CREATE TABLE stock_adjustment
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    ingredient_id            UUID NOT NULL,

    warehouse_id               UUID NOT NULL,

    adjustment_type              adjustment_type NOT NULL,

    quantity                       NUMERIC(18,4) NOT NULL,

    reason                            TEXT,

    created_by                         UUID,

    created_at                           TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_stock_adjustment_ingredient
        FOREIGN KEY(ingredient_id)
        REFERENCES ingredient(id),

    CONSTRAINT fk_stock_adjustment_warehouse
        FOREIGN KEY(warehouse_id)
        REFERENCES warehouse(id),

    CONSTRAINT fk_stock_adjustment_user
        FOREIGN KEY(created_by)
        REFERENCES app_user(id)
);

CREATE INDEX idx_stock_adjustment_ingredient
ON stock_adjustment(ingredient_id);

------------------------------------------------------------
-- STOCK TRANSFER (CHUYỂN KHO GIỮA CHI NHÁNH - SCALE READY)
------------------------------------------------------------

CREATE TABLE stock_transfer
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    transfer_code            VARCHAR(50) UNIQUE NOT NULL,

    from_warehouse_id          UUID NOT NULL,

    to_warehouse_id               UUID NOT NULL,

    status                           transfer_status DEFAULT 'DRAFT',

    note                                TEXT,

    created_by                           UUID,

    created_at                             TIMESTAMPTZ DEFAULT NOW(),

    completed_at                             TIMESTAMPTZ,

    version                                    INT DEFAULT 1,

    CONSTRAINT fk_stock_transfer_from
        FOREIGN KEY(from_warehouse_id)
        REFERENCES warehouse(id),

    CONSTRAINT fk_stock_transfer_to
        FOREIGN KEY(to_warehouse_id)
        REFERENCES warehouse(id),

    CONSTRAINT fk_stock_transfer_user
        FOREIGN KEY(created_by)
        REFERENCES app_user(id),

    CONSTRAINT ck_stock_transfer_diff
        CHECK(from_warehouse_id <> to_warehouse_id)
);

CREATE TABLE stock_transfer_item
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    transfer_id              UUID NOT NULL,

    ingredient_id              UUID NOT NULL,

    quantity                     NUMERIC(18,4) NOT NULL,

    CONSTRAINT fk_transfer_item_transfer
        FOREIGN KEY(transfer_id)
        REFERENCES stock_transfer(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_transfer_item_ingredient
        FOREIGN KEY(ingredient_id)
        REFERENCES ingredient(id)
);

CREATE INDEX idx_transfer_item_transfer
ON stock_transfer_item(transfer_id);

------------------------------------------------------------
-- FUNCTION: UPSERT INVENTORY STOCK
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_upsert_inventory_stock
(
    p_ingredient_id UUID,
    p_warehouse_id UUID,
    p_delta_quantity NUMERIC
)
RETURNS VOID
LANGUAGE plpgsql
AS
$$
BEGIN

    INSERT INTO inventory_stock(ingredient_id, warehouse_id, quantity_on_hand, updated_at)
    VALUES(p_ingredient_id, p_warehouse_id, p_delta_quantity, NOW())
    ON CONFLICT(ingredient_id, warehouse_id)
    DO UPDATE
    SET
        quantity_on_hand = inventory_stock.quantity_on_hand + p_delta_quantity,
        updated_at = NOW();

END;
$$;

------------------------------------------------------------
-- FUNCTION: IMPORT STOCK (tạo lô hàng mới + ghi ledger)
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_import_stock
(
    p_ingredient_id UUID,
    p_warehouse_id UUID,
    p_quantity NUMERIC,
    p_import_price NUMERIC,
    p_expired_at TIMESTAMPTZ,
    p_supplier_id UUID,
    p_purchase_item_id UUID,
    p_created_by UUID
)
RETURNS UUID
LANGUAGE plpgsql
AS
$$
DECLARE

    v_batch_id UUID;

    v_batch_code VARCHAR(50);

BEGIN

    v_batch_code := 'BATCH-' || TO_CHAR(NOW(),'YYYYMMDDHH24MISS') || '-' || SUBSTRING(gen_random_uuid()::TEXT,1,4);

    INSERT INTO inventory_batch
    (
        ingredient_id, warehouse_id, batch_code, supplier_id,
        purchase_item_id, quantity, remain_quantity, import_price,
        expired_at
    )
    VALUES
    (
        p_ingredient_id, p_warehouse_id, v_batch_code, p_supplier_id,
        p_purchase_item_id, p_quantity, p_quantity, p_import_price,
        p_expired_at
    )
    RETURNING id INTO v_batch_id;

    INSERT INTO stock_movement
    (
        ingredient_id, warehouse_id, batch_id, movement_type,
        quantity, unit_cost, reference_type, reference_id, created_by
    )
    VALUES
    (
        p_ingredient_id, p_warehouse_id, v_batch_id, 'IMPORT',
        p_quantity, p_import_price, 'PURCHASE_ITEM', p_purchase_item_id, p_created_by
    );

    PERFORM fn_upsert_inventory_stock(p_ingredient_id, p_warehouse_id, p_quantity);

    -- cập nhật giá nhập mới nhất vào bảng giá nguyên liệu (single source of truth cho Cost Engine)
    INSERT INTO ingredient_price_history(ingredient_id, supplier_id, unit_price, note)
    VALUES(p_ingredient_id, p_supplier_id, p_import_price, 'Auto từ phiếu nhập kho');

    RETURN v_batch_id;

END;
$$;

------------------------------------------------------------
-- FUNCTION: CONSUME INGREDIENT (FEFO - First Expired First Out)
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_consume_ingredient
(
    p_ingredient_id UUID,
    p_warehouse_id UUID,
    p_quantity NUMERIC,
    p_reference_type VARCHAR,
    p_reference_id UUID,
    p_created_by UUID
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS
$$
DECLARE

    v_batch RECORD;

    v_remaining_to_consume NUMERIC := p_quantity;

    v_take NUMERIC;

    v_shortage NUMERIC := 0;

BEGIN

    FOR v_batch IN
        SELECT id, remain_quantity, import_price
        FROM inventory_batch
        WHERE ingredient_id = p_ingredient_id
          AND warehouse_id = p_warehouse_id
          AND remain_quantity > 0
        ORDER BY expired_at ASC NULLS LAST, imported_at ASC
        FOR UPDATE
    LOOP

        EXIT WHEN v_remaining_to_consume <= 0;

        v_take := LEAST(v_batch.remain_quantity, v_remaining_to_consume);

        UPDATE inventory_batch
        SET remain_quantity = remain_quantity - v_take,
            updated_at = NOW()
        WHERE id = v_batch.id;

        INSERT INTO stock_movement
        (
            ingredient_id, warehouse_id, batch_id, movement_type,
            quantity, unit_cost, reference_type, reference_id, created_by
        )
        VALUES
        (
            p_ingredient_id, p_warehouse_id, v_batch.id, 'ORDER_CONSUME',
            v_take, v_batch.import_price, p_reference_type, p_reference_id, p_created_by
        );

        v_remaining_to_consume := v_remaining_to_consume - v_take;

    END LOOP;

    IF v_remaining_to_consume > 0 THEN
        v_shortage := v_remaining_to_consume;
    END IF;

    PERFORM fn_upsert_inventory_stock(p_ingredient_id, p_warehouse_id, -(p_quantity - v_shortage));

    RETURN v_shortage;

END;
$$;

------------------------------------------------------------
-- UPDATE TRIGGER
------------------------------------------------------------

CREATE TRIGGER trg_warehouse_update
BEFORE UPDATE
ON warehouse
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_inventory_batch_update
BEFORE UPDATE
ON inventory_batch
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_stock_transfer_update
BEFORE UPDATE
ON stock_transfer
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

/*
===========================================================
Beverage Operating System
07_purchase.sql
Supplier & Purchase Order (Nhập kho)
===========================================================
*/

------------------------------------------------------------
-- ENUM
------------------------------------------------------------

CREATE TYPE purchase_status AS ENUM
(
    'DRAFT',
    'SUBMITTED',
    'APPROVED',
    'PARTIAL_RECEIVED',
    'RECEIVED',
    'CANCELLED'
);

------------------------------------------------------------
-- SUPPLIER
------------------------------------------------------------

CREATE TABLE supplier
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    supplier_code            VARCHAR(50) UNIQUE NOT NULL,

    supplier_name              VARCHAR(255) NOT NULL,

    phone                         VARCHAR(20),

    email                           CITEXT,

    address                           TEXT,

    tax_code                           VARCHAR(50),

    payment_term_day                     INT DEFAULT 0,

    note                                    TEXT,

    is_active                                BOOLEAN DEFAULT TRUE,

    created_at                                 TIMESTAMPTZ DEFAULT NOW(),

    updated_at                                   TIMESTAMPTZ DEFAULT NOW(),

    deleted_at                                     TIMESTAMPTZ,

    version                                          INT DEFAULT 1
);

CREATE INDEX idx_supplier_name
ON supplier(supplier_name);

CREATE INDEX idx_supplier_phone
ON supplier(phone);

-- Ràng buộc FK còn thiếu ở inventory_batch (06_inventory.sql) do supplier
-- chưa tồn tại tại thời điểm đó, nay bổ sung:

ALTER TABLE inventory_batch
ADD CONSTRAINT fk_inventory_batch_supplier
    FOREIGN KEY(supplier_id)
    REFERENCES supplier(id);

------------------------------------------------------------
-- PURCHASE ORDER (PHIẾU ĐẶT HÀNG NHÀ CUNG CẤP)
------------------------------------------------------------

CREATE TABLE purchase_order
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    po_code                   VARCHAR(50) UNIQUE NOT NULL,

    supplier_id                 UUID NOT NULL,

    warehouse_id                   UUID NOT NULL,

    status                            purchase_status DEFAULT 'DRAFT',

    payment_status                      payment_status DEFAULT 'UNPAID',

    order_date                            DATE DEFAULT CURRENT_DATE,

    expected_date                           DATE,

    subtotal_amount                           NUMERIC(18,2) DEFAULT 0,

    total_amount                                NUMERIC(18,2) DEFAULT 0,

    note                                          TEXT,

    created_by                                      UUID,

    created_at                                        TIMESTAMPTZ DEFAULT NOW(),

    updated_at                                          TIMESTAMPTZ DEFAULT NOW(),

    version                                               INT DEFAULT 1,

    CONSTRAINT fk_purchase_order_supplier
        FOREIGN KEY(supplier_id)
        REFERENCES supplier(id),

    CONSTRAINT fk_purchase_order_warehouse
        FOREIGN KEY(warehouse_id)
        REFERENCES warehouse(id),

    CONSTRAINT fk_purchase_order_user
        FOREIGN KEY(created_by)
        REFERENCES app_user(id)
);

CREATE INDEX idx_purchase_order_supplier
ON purchase_order(supplier_id);

CREATE INDEX idx_purchase_order_status
ON purchase_order(status);

CREATE INDEX idx_purchase_order_code
ON purchase_order(po_code);

------------------------------------------------------------
-- PURCHASE ITEM
------------------------------------------------------------

CREATE TABLE purchase_item
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    purchase_order_id         UUID NOT NULL,

    ingredient_id                UUID NOT NULL,

    quantity                       NUMERIC(18,4) NOT NULL,

    unit_price                       NUMERIC(18,4) NOT NULL DEFAULT 0,

    received_quantity                  NUMERIC(18,4) NOT NULL DEFAULT 0,

    total_price                          NUMERIC(18,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,

    CONSTRAINT fk_purchase_item_order
        FOREIGN KEY(purchase_order_id)
        REFERENCES purchase_order(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_purchase_item_ingredient
        FOREIGN KEY(ingredient_id)
        REFERENCES ingredient(id)
);

CREATE INDEX idx_purchase_item_order
ON purchase_item(purchase_order_id);

-- Ràng buộc FK còn thiếu ở inventory_batch (06_inventory.sql):

ALTER TABLE inventory_batch
ADD CONSTRAINT fk_inventory_batch_purchase_item
    FOREIGN KEY(purchase_item_id)
    REFERENCES purchase_item(id);

------------------------------------------------------------
-- PURCHASE PAYMENT
------------------------------------------------------------

CREATE TABLE purchase_payment
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    purchase_order_id         UUID NOT NULL,

    amount                       NUMERIC(18,2) NOT NULL,

    payment_method                 payment_method,

    paid_at                          TIMESTAMPTZ DEFAULT NOW(),

    note                               TEXT,

    created_by                          UUID,

    created_at                            TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_purchase_payment_order
        FOREIGN KEY(purchase_order_id)
        REFERENCES purchase_order(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_purchase_payment_user
        FOREIGN KEY(created_by)
        REFERENCES app_user(id)
);

CREATE INDEX idx_purchase_payment_order
ON purchase_payment(purchase_order_id);

------------------------------------------------------------
-- FUNCTION: NHẬN HÀNG (RECEIVE) - SINH LÔ HÀNG + GHI SỔ KHO
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_receive_purchase_item
(
    p_purchase_item_id UUID,
    p_receive_quantity NUMERIC,
    p_expired_at TIMESTAMPTZ,
    p_created_by UUID
)
RETURNS UUID
LANGUAGE plpgsql
AS
$$
DECLARE

    v_item RECORD;

    v_order RECORD;

    v_batch_id UUID;

    v_total_ordered NUMERIC;

    v_total_received NUMERIC;

BEGIN

    SELECT * INTO v_item
    FROM purchase_item
    WHERE id = p_purchase_item_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'purchase_item % not found', p_purchase_item_id;
    END IF;

    SELECT * INTO v_order
    FROM purchase_order
    WHERE id = v_item.purchase_order_id
    FOR UPDATE;

    v_batch_id := fn_import_stock
    (
        v_item.ingredient_id,
        v_order.warehouse_id,
        p_receive_quantity,
        v_item.unit_price,
        p_expired_at,
        v_order.supplier_id,
        p_purchase_item_id,
        p_created_by
    );

    UPDATE purchase_item
    SET received_quantity = received_quantity + p_receive_quantity
    WHERE id = p_purchase_item_id;

    SELECT SUM(quantity), SUM(received_quantity)
    INTO v_total_ordered, v_total_received
    FROM purchase_item
    WHERE purchase_order_id = v_item.purchase_order_id;

    UPDATE purchase_order
    SET status = CASE
                    WHEN v_total_received >= v_total_ordered THEN 'RECEIVED'
                    WHEN v_total_received > 0 THEN 'PARTIAL_RECEIVED'
                    ELSE status
                 END,
        total_amount = (SELECT COALESCE(SUM(total_price),0) FROM purchase_item WHERE purchase_order_id = v_item.purchase_order_id)
    WHERE id = v_item.purchase_order_id;

    RETURN v_batch_id;

END;
$$;

------------------------------------------------------------
-- UPDATE TRIGGER
------------------------------------------------------------

CREATE TRIGGER trg_supplier_update
BEFORE UPDATE
ON supplier
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_purchase_order_update
BEFORE UPDATE
ON purchase_order
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

/*
===========================================================
Beverage Operating System
08_order.sql
Order (Đơn hàng) - Order Item - Timeline - Payment
===========================================================
*/

------------------------------------------------------------
-- ENUM
------------------------------------------------------------

CREATE TYPE order_type AS ENUM
(
    'DINE_IN',
    'TAKE_AWAY',
    'DELIVERY'
);

CREATE TYPE order_source AS ENUM
(
    'QR',
    'WEBSITE',
    'APP',
    'POS'
);

------------------------------------------------------------
-- SEQUENCE (SINH MÃ ĐƠN HÀNG)
------------------------------------------------------------

CREATE SEQUENCE seq_order_code START 1;

------------------------------------------------------------
-- ORDER
-- Đơn hàng là "sự kiện khởi đầu" (event trigger) cho toàn bộ
-- chuỗi workflow: Kitchen - Inventory - Cost - Dashboard -
-- Notification (xem chi tiết ở 11_trigger.sql)
------------------------------------------------------------

CREATE TABLE orders
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    order_code                VARCHAR(50) UNIQUE NOT NULL,

    customer_id                  UUID,

    warehouse_id                    UUID NOT NULL,

    order_type                        order_type NOT NULL DEFAULT 'TAKE_AWAY',

    order_source                        order_source NOT NULL DEFAULT 'QR',

    status                                order_status DEFAULT 'NEW',

    payment_status                         payment_status DEFAULT 'UNPAID',

    payment_method                           payment_method,

    table_no                                   VARCHAR(20),

    subtotal_amount                              NUMERIC(18,2) DEFAULT 0,

    discount_amount                                NUMERIC(18,2) DEFAULT 0,

    shipping_fee                                     NUMERIC(18,2) DEFAULT 0,

    tax_amount                                         NUMERIC(18,2) DEFAULT 0,

    total_amount                                         NUMERIC(18,2) DEFAULT 0,

    note                                                   TEXT,

    cancel_reason                                            TEXT,

    confirmed_at                                               TIMESTAMPTZ,

    completed_at                                                 TIMESTAMPTZ,

    cancelled_at                                                   TIMESTAMPTZ,

    created_by                                                       UUID,

    created_at                                                         TIMESTAMPTZ DEFAULT NOW(),

    updated_at                                                           TIMESTAMPTZ DEFAULT NOW(),

    version                                                                INT DEFAULT 1,

    CONSTRAINT fk_order_customer
        FOREIGN KEY(customer_id)
        REFERENCES customer(id),

    CONSTRAINT fk_order_warehouse
        FOREIGN KEY(warehouse_id)
        REFERENCES warehouse(id),

    CONSTRAINT fk_order_user
        FOREIGN KEY(created_by)
        REFERENCES app_user(id)
);

CREATE INDEX idx_order_code
ON orders(order_code);

CREATE INDEX idx_order_customer
ON orders(customer_id);

CREATE INDEX idx_order_status
ON orders(status);

CREATE INDEX idx_order_created
ON orders(created_at);

------------------------------------------------------------
-- ORDER ITEM
------------------------------------------------------------

CREATE TABLE order_item
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    order_id                  UUID NOT NULL,

    product_variant_id           UUID NOT NULL,

    recipe_version_id               UUID,

    quantity                          NUMERIC(10,2) NOT NULL DEFAULT 1,

    unit_price                          NUMERIC(18,2) NOT NULL,

    discount_amount                       NUMERIC(18,2) DEFAULT 0,

    ingredient_cost_amount                  NUMERIC(18,2) DEFAULT 0,

    total_price                               NUMERIC(18,2) NOT NULL,

    note                                         TEXT,

    created_at                                     TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_order_item_order
        FOREIGN KEY(order_id)
        REFERENCES orders(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_order_item_variant
        FOREIGN KEY(product_variant_id)
        REFERENCES product_variant(id),

    CONSTRAINT fk_order_item_recipe_version
        FOREIGN KEY(recipe_version_id)
        REFERENCES recipe_version(id)
);

CREATE INDEX idx_order_item_order
ON order_item(order_id);

CREATE INDEX idx_order_item_variant
ON order_item(product_variant_id);

------------------------------------------------------------
-- ORDER ITEM TOPPING
------------------------------------------------------------

CREATE TABLE order_item_topping
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    order_item_id             UUID NOT NULL,

    topping_id                   UUID NOT NULL,

    quantity                       INT NOT NULL DEFAULT 1,

    unit_price                       NUMERIC(18,2) DEFAULT 0,

    CONSTRAINT fk_order_item_topping_item
        FOREIGN KEY(order_item_id)
        REFERENCES order_item(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_order_item_topping_topping
        FOREIGN KEY(topping_id)
        REFERENCES topping(id)
);

CREATE INDEX idx_order_item_topping_item
ON order_item_topping(order_item_id);

------------------------------------------------------------
-- ORDER ITEM MODIFIER
------------------------------------------------------------

CREATE TABLE order_item_modifier
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    order_item_id             UUID NOT NULL,

    modifier_option_id           UUID NOT NULL,

    extra_price                    NUMERIC(18,2) DEFAULT 0,

    CONSTRAINT fk_order_item_modifier_item
        FOREIGN KEY(order_item_id)
        REFERENCES order_item(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_order_item_modifier_option
        FOREIGN KEY(modifier_option_id)
        REFERENCES modifier_option(id)
);

CREATE INDEX idx_order_item_modifier_item
ON order_item_modifier(order_item_id);

------------------------------------------------------------
-- ORDER TIMELINE (LỊCH SỬ TRẠNG THÁI ĐƠN HÀNG)
------------------------------------------------------------

CREATE TABLE order_timeline
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    order_id                  UUID NOT NULL,

    from_status                  order_status,

    to_status                       order_status NOT NULL,

    action                            VARCHAR(100),

    note                                 TEXT,

    created_by                            UUID,

    created_at                              TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_order_timeline_order
        FOREIGN KEY(order_id)
        REFERENCES orders(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_order_timeline_user
        FOREIGN KEY(created_by)
        REFERENCES app_user(id)
);

CREATE INDEX idx_order_timeline_order
ON order_timeline(order_id);

------------------------------------------------------------
-- PAYMENT
------------------------------------------------------------

CREATE TABLE payment
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    order_id                  UUID NOT NULL,

    amount                       NUMERIC(18,2) NOT NULL,

    payment_method                 payment_method NOT NULL,

    transaction_code                 VARCHAR(100),

    status                              payment_status DEFAULT 'PENDING',

    paid_at                               TIMESTAMPTZ,

    created_at                              TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_payment_order
        FOREIGN KEY(order_id)
        REFERENCES orders(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_payment_order
ON payment(order_id);

------------------------------------------------------------
-- FUNCTION: SINH MÃ ĐƠN HÀNG
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_generate_order_code()
RETURNS VARCHAR
LANGUAGE plpgsql
AS
$$
DECLARE

    v_code VARCHAR(50);

BEGIN

    v_code := 'ORD' || TO_CHAR(NOW(),'YYMMDD') || LPAD(NEXTVAL('seq_order_code')::TEXT,5,'0');

    RETURN v_code;

END;
$$;

------------------------------------------------------------
-- UPDATE TRIGGER
------------------------------------------------------------

CREATE TRIGGER trg_order_update
BEFORE UPDATE
ON orders
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

/*
===========================================================
Beverage Operating System
09_delivery.sql
Delivery (Giao hàng tự vận hành - không qua Grab/Shopee)
===========================================================
*/

------------------------------------------------------------
-- ENUM
------------------------------------------------------------

CREATE TYPE delivery_status AS ENUM
(
    'WAITING',
    'ASSIGNED',
    'PICKED_UP',
    'DELIVERING',
    'DELIVERED',
    'FAILED',
    'CANCELLED'
);

------------------------------------------------------------
-- DELIVERY
------------------------------------------------------------

CREATE TABLE delivery
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    order_id                  UUID UNIQUE NOT NULL,

    delivery_code                VARCHAR(50) UNIQUE NOT NULL,

    delivery_user_id                UUID,

    receiver_name                     VARCHAR(255),

    receiver_phone                      VARCHAR(20),

    province                              VARCHAR(100),

    district                                VARCHAR(100),

    ward                                      VARCHAR(100),

    address                                     TEXT,

    latitude                                      NUMERIC(10,7),

    longitude                                       NUMERIC(10,7),

    distance_km                                       NUMERIC(10,2),

    delivery_fee                                        NUMERIC(18,2) DEFAULT 0,

    status                                                delivery_status DEFAULT 'WAITING',

    assigned_at                                             TIMESTAMPTZ,

    picked_up_at                                              TIMESTAMPTZ,

    delivering_at                                               TIMESTAMPTZ,

    delivered_at                                                  TIMESTAMPTZ,

    failed_reason                                                   TEXT,

    note                                                              TEXT,

    created_at                                                          TIMESTAMPTZ DEFAULT NOW(),

    updated_at                                                            TIMESTAMPTZ DEFAULT NOW(),

    version                                                                 INT DEFAULT 1,

    CONSTRAINT fk_delivery_order
        FOREIGN KEY(order_id)
        REFERENCES orders(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_delivery_user
        FOREIGN KEY(delivery_user_id)
        REFERENCES app_user(id)
);

CREATE INDEX idx_delivery_order
ON delivery(order_id);

CREATE INDEX idx_delivery_user
ON delivery(delivery_user_id);

CREATE INDEX idx_delivery_status
ON delivery(status);

------------------------------------------------------------
-- DELIVERY TRACKING (VỊ TRÍ REAL-TIME)
------------------------------------------------------------

CREATE TABLE delivery_tracking
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    delivery_id               UUID NOT NULL,

    latitude                     NUMERIC(10,7) NOT NULL,

    longitude                      NUMERIC(10,7) NOT NULL,

    tracked_at                       TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_delivery_tracking_delivery
        FOREIGN KEY(delivery_id)
        REFERENCES delivery(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_delivery_tracking_delivery
ON delivery_tracking(delivery_id);

------------------------------------------------------------
-- DELIVERY PROOF (BẰNG CHỨNG GIAO HÀNG)
------------------------------------------------------------

CREATE TABLE delivery_proof
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    delivery_id               UUID NOT NULL,

    image_url                    TEXT,

    signature_url                  TEXT,

    note                              TEXT,

    created_at                          TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_delivery_proof_delivery
        FOREIGN KEY(delivery_id)
        REFERENCES delivery(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- DELIVERY RATING
------------------------------------------------------------

CREATE TABLE delivery_rating
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    delivery_id               UUID NOT NULL,

    customer_id                  UUID,

    rating                          SMALLINT NOT NULL CHECK(rating BETWEEN 1 AND 5),

    comment                           TEXT,

    created_at                          TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_delivery_rating_delivery
        FOREIGN KEY(delivery_id)
        REFERENCES delivery(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_delivery_rating_customer
        FOREIGN KEY(customer_id)
        REFERENCES customer(id)
);

CREATE INDEX idx_delivery_rating_delivery
ON delivery_rating(delivery_id);

------------------------------------------------------------
-- UPDATE TRIGGER
------------------------------------------------------------

CREATE TRIGGER trg_delivery_update
BEFORE UPDATE
ON delivery
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

/*
===========================================================
Beverage Operating System
10_dashboard.sql
Dashboard / Report Summary (bảng tổng hợp phục vụ đọc nhanh)

Toàn bộ Dashboard đều được "sinh ra" từ Recipe -> Inventory ->
Order -> Cost theo đúng triết lý Data First / Single Source
of Truth. Các bảng dưới đây chỉ là lớp cache tổng hợp
(denormalized) để tránh tính toán lại từ đầu mỗi lần load.
===========================================================
*/

------------------------------------------------------------
-- DAILY SALES SUMMARY
------------------------------------------------------------

CREATE TABLE daily_sales_summary
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    summary_date              DATE NOT NULL,

    warehouse_id                 UUID,

    total_order                    INT DEFAULT 0,

    total_customer                   INT DEFAULT 0,

    gross_revenue                      NUMERIC(18,2) DEFAULT 0,

    discount_amount                      NUMERIC(18,2) DEFAULT 0,

    net_revenue                            NUMERIC(18,2) DEFAULT 0,

    total_cost                               NUMERIC(18,2) DEFAULT 0,

    gross_profit                               NUMERIC(18,2) DEFAULT 0,

    created_at                                   TIMESTAMPTZ DEFAULT NOW(),

    updated_at                                     TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_daily_sales_warehouse
        FOREIGN KEY(warehouse_id)
        REFERENCES warehouse(id),

    CONSTRAINT uq_daily_sales_summary
        UNIQUE(summary_date, warehouse_id)
);

CREATE INDEX idx_daily_sales_date
ON daily_sales_summary(summary_date);

------------------------------------------------------------
-- PRODUCT SALES SUMMARY (TOP MÓN)
------------------------------------------------------------

CREATE TABLE product_sales_summary
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    summary_date              DATE NOT NULL,

    product_variant_id           UUID NOT NULL,

    quantity_sold                   NUMERIC(18,2) DEFAULT 0,

    revenue                           NUMERIC(18,2) DEFAULT 0,

    cost                                NUMERIC(18,2) DEFAULT 0,

    profit                                NUMERIC(18,2) DEFAULT 0,

    CONSTRAINT fk_product_sales_variant
        FOREIGN KEY(product_variant_id)
        REFERENCES product_variant(id),

    CONSTRAINT uq_product_sales_summary
        UNIQUE(summary_date, product_variant_id)
);

CREATE INDEX idx_product_sales_date
ON product_sales_summary(summary_date);

CREATE INDEX idx_product_sales_variant
ON product_sales_summary(product_variant_id);

------------------------------------------------------------
-- INGREDIENT USAGE SUMMARY (NGUYÊN LIỆU SẮP HẾT / DỰ BÁO NHẬP)
------------------------------------------------------------

CREATE TABLE ingredient_usage_summary
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    summary_date              DATE NOT NULL,

    ingredient_id                UUID NOT NULL,

    quantity_used                   NUMERIC(18,4) DEFAULT 0,

    usage_cost                        NUMERIC(18,2) DEFAULT 0,

    CONSTRAINT fk_ingredient_usage_ingredient
        FOREIGN KEY(ingredient_id)
        REFERENCES ingredient(id),

    CONSTRAINT uq_ingredient_usage_summary
        UNIQUE(summary_date, ingredient_id)
);

CREATE INDEX idx_ingredient_usage_date
ON ingredient_usage_summary(summary_date);

------------------------------------------------------------
-- CUSTOMER SALES SUMMARY (TOP KHÁCH)
------------------------------------------------------------

CREATE TABLE customer_sales_summary
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    summary_date              DATE NOT NULL,

    customer_id                  UUID NOT NULL,

    order_count                     INT DEFAULT 0,

    total_spent                       NUMERIC(18,2) DEFAULT 0,

    CONSTRAINT fk_customer_sales_customer
        FOREIGN KEY(customer_id)
        REFERENCES customer(id),

    CONSTRAINT uq_customer_sales_summary
        UNIQUE(summary_date, customer_id)
);

CREATE INDEX idx_customer_sales_date
ON customer_sales_summary(summary_date);

------------------------------------------------------------
-- DASHBOARD KPI SNAPSHOT (TỔNG QUAN NHANH)
------------------------------------------------------------

CREATE TABLE dashboard_kpi_snapshot
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    snapshot_date              DATE UNIQUE NOT NULL,

    total_revenue                 NUMERIC(18,2) DEFAULT 0,

    total_profit                     NUMERIC(18,2) DEFAULT 0,

    total_order                        INT DEFAULT 0,

    new_customer_count                   INT DEFAULT 0,

    low_stock_count                        INT DEFAULT 0,

    top_product_id                           UUID,

    created_at                                 TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_dashboard_top_product
        FOREIGN KEY(top_product_id)
        REFERENCES product_variant(id)
);

------------------------------------------------------------
-- FUNCTION: REFRESH DASHBOARD THEO NGÀY
-- Được gọi bởi scheduler (cron / pg_cron) hoặc trigger cuối
-- ngày; cũng có thể gọi thủ công để backfill dữ liệu cũ
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_refresh_daily_dashboard
(
    p_date DATE
)
RETURNS VOID
LANGUAGE plpgsql
AS
$$
BEGIN

    -- 1. Doanh thu / lợi nhuận theo kho
    INSERT INTO daily_sales_summary
    (
        summary_date, warehouse_id, total_order, total_customer,
        gross_revenue, discount_amount, net_revenue, total_cost, gross_profit
    )
    SELECT
        p_date,
        o.warehouse_id,
        COUNT(DISTINCT o.id),
        COUNT(DISTINCT o.customer_id),
        COALESCE(SUM(oi.total_price + oi.discount_amount),0),
        COALESCE(SUM(oi.discount_amount),0),
        COALESCE(SUM(oi.total_price),0),
        COALESCE(SUM(oi.ingredient_cost_amount),0),
        COALESCE(SUM(oi.total_price - oi.ingredient_cost_amount),0)
    FROM orders o
    JOIN order_item oi ON oi.order_id = o.id
    WHERE o.status = 'COMPLETED'
      AND DATE(o.completed_at) = p_date
    GROUP BY o.warehouse_id
    ON CONFLICT(summary_date, warehouse_id)
    DO UPDATE
    SET
        total_order = EXCLUDED.total_order,
        total_customer = EXCLUDED.total_customer,
        gross_revenue = EXCLUDED.gross_revenue,
        discount_amount = EXCLUDED.discount_amount,
        net_revenue = EXCLUDED.net_revenue,
        total_cost = EXCLUDED.total_cost,
        gross_profit = EXCLUDED.gross_profit,
        updated_at = NOW();

    -- 2. Top món
    INSERT INTO product_sales_summary
    (
        summary_date, product_variant_id, quantity_sold, revenue, cost, profit
    )
    SELECT
        p_date,
        oi.product_variant_id,
        SUM(oi.quantity),
        SUM(oi.total_price),
        SUM(oi.ingredient_cost_amount),
        SUM(oi.total_price - oi.ingredient_cost_amount)
    FROM orders o
    JOIN order_item oi ON oi.order_id = o.id
    WHERE o.status = 'COMPLETED'
      AND DATE(o.completed_at) = p_date
    GROUP BY oi.product_variant_id
    ON CONFLICT(summary_date, product_variant_id)
    DO UPDATE
    SET
        quantity_sold = EXCLUDED.quantity_sold,
        revenue = EXCLUDED.revenue,
        cost = EXCLUDED.cost,
        profit = EXCLUDED.profit;

    -- 3. Nguyên liệu tiêu thụ
    INSERT INTO ingredient_usage_summary
    (
        summary_date, ingredient_id, quantity_used, usage_cost
    )
    SELECT
        p_date,
        sm.ingredient_id,
        SUM(sm.quantity),
        SUM(sm.quantity * sm.unit_cost)
    FROM stock_movement sm
    WHERE sm.movement_type = 'ORDER_CONSUME'
      AND DATE(sm.created_at) = p_date
    GROUP BY sm.ingredient_id
    ON CONFLICT(summary_date, ingredient_id)
    DO UPDATE
    SET
        quantity_used = EXCLUDED.quantity_used,
        usage_cost = EXCLUDED.usage_cost;

    -- 4. Top khách
    INSERT INTO customer_sales_summary
    (
        summary_date, customer_id, order_count, total_spent
    )
    SELECT
        p_date,
        o.customer_id,
        COUNT(DISTINCT o.id),
        SUM(o.total_amount)
    FROM orders o
    WHERE o.status = 'COMPLETED'
      AND o.customer_id IS NOT NULL
      AND DATE(o.completed_at) = p_date
    GROUP BY o.customer_id
    ON CONFLICT(summary_date, customer_id)
    DO UPDATE
    SET
        order_count = EXCLUDED.order_count,
        total_spent = EXCLUDED.total_spent;

    -- 5. KPI tổng quan
    INSERT INTO dashboard_kpi_snapshot
    (
        snapshot_date, total_revenue, total_profit, total_order,
        new_customer_count, low_stock_count, top_product_id
    )
    SELECT
        p_date,
        COALESCE((SELECT SUM(net_revenue) FROM daily_sales_summary WHERE summary_date = p_date),0),
        COALESCE((SELECT SUM(gross_profit) FROM daily_sales_summary WHERE summary_date = p_date),0),
        COALESCE((SELECT SUM(total_order) FROM daily_sales_summary WHERE summary_date = p_date),0),
        COALESCE((SELECT COUNT(*) FROM customer WHERE DATE(created_at) = p_date),0),
        COALESCE((SELECT COUNT(*) FROM inventory_stock ist JOIN ingredient i ON i.id = ist.ingredient_id WHERE ist.quantity_on_hand <= i.minimum_stock),0),
        (SELECT product_variant_id FROM product_sales_summary WHERE summary_date = p_date ORDER BY quantity_sold DESC LIMIT 1)
    ON CONFLICT(snapshot_date)
    DO UPDATE
    SET
        total_revenue = EXCLUDED.total_revenue,
        total_profit = EXCLUDED.total_profit,
        total_order = EXCLUDED.total_order,
        new_customer_count = EXCLUDED.new_customer_count,
        low_stock_count = EXCLUDED.low_stock_count,
        top_product_id = EXCLUDED.top_product_id;

END;
$$;

/*
===========================================================
Beverage Operating System
11_trigger.sql
Automation / Event-Driven Workflow

Triết lý: Order chỉ là sự kiện khởi đầu, các module khác
tự động phản ứng theo chuỗi:

Khách đặt hàng
    |
    v
Tạo Order
    |
    +-- Gửi thông báo cho Kitchen
    +-- Trừ tồn kho theo Recipe (FEFO)
    +-- Tính Cost snapshot cho từng Order Item
    +-- Ghi Timeline
    +-- Thông báo cho khách
    +-- Khi hoàn tất -> cập nhật điểm / hạng khách hàng
    +-- Khi tồn kho chạm ngưỡng -> cảnh báo nhập hàng
===========================================================
*/

------------------------------------------------------------
-- ENUM
------------------------------------------------------------

CREATE TYPE notification_type AS ENUM
(
    'ORDER',
    'DELIVERY',
    'INVENTORY',
    'SYSTEM',
    'PROMOTION'
);

CREATE TYPE notification_channel AS ENUM
(
    'PUSH',
    'SMS',
    'EMAIL',
    'ZALO',
    'IN_APP'
);

CREATE TYPE recipient_type AS ENUM
(
    'CUSTOMER',
    'STAFF'
);

------------------------------------------------------------
-- NOTIFICATION
------------------------------------------------------------

CREATE TABLE notification
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    notification_type          notification_type NOT NULL,

    channel                       notification_channel DEFAULT 'IN_APP',

    recipient_type                   recipient_type NOT NULL,

    recipient_id                       UUID,

    title                                 VARCHAR(255),

    message                                TEXT,

    reference_type                           VARCHAR(50),

    reference_id                               UUID,

    is_read                                      BOOLEAN DEFAULT FALSE,

    created_at                                     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notification_recipient
ON notification(recipient_type, recipient_id);

CREATE INDEX idx_notification_reference
ON notification(reference_type, reference_id);

CREATE INDEX idx_notification_unread
ON notification(is_read);

------------------------------------------------------------
-- TRIGGER FUNCTION 1
-- AFTER INSERT ON order_item
-- Recipe đọc -> Kho trừ (FEFO) -> Cost tính -> lưu snapshot
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_trg_order_item_consume_inventory()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
DECLARE

    v_warehouse_id UUID;

    v_recipe_version_id UUID;

    v_ingredient RECORD;

    v_shortage NUMERIC;

    v_total_cost NUMERIC := 0;

    v_created_by UUID;

BEGIN

    SELECT warehouse_id, created_by INTO v_warehouse_id, v_created_by
    FROM orders
    WHERE id = NEW.order_id;

    -- Lấy recipe_version đang hiệu lực (is_current) của biến thể sản phẩm
    SELECT rv.id INTO v_recipe_version_id
    FROM recipe r
    JOIN recipe_version rv ON rv.recipe_id = r.id AND rv.is_current = TRUE
    WHERE r.product_variant_id = NEW.product_variant_id
    LIMIT 1;

    IF v_recipe_version_id IS NULL THEN
        -- Sản phẩm không có công thức (VD: topping bán rời) -> bỏ qua trừ kho
        RETURN NEW;
    END IF;

    UPDATE order_item
    SET recipe_version_id = v_recipe_version_id
    WHERE id = NEW.id;

    FOR v_ingredient IN
        SELECT ingredient_id, quantity
        FROM recipe_ingredient
        WHERE recipe_version_id = v_recipe_version_id
    LOOP

        v_shortage := fn_consume_ingredient
        (
            v_ingredient.ingredient_id,
            v_warehouse_id,
            v_ingredient.quantity * NEW.quantity,
            'ORDER_ITEM',
            NEW.id,
            v_created_by
        );

        IF v_shortage > 0 THEN
            INSERT INTO notification
            (
                notification_type, channel, recipient_type, recipient_id,
                title, message, reference_type, reference_id
            )
            VALUES
            (
                'INVENTORY', 'IN_APP', 'STAFF', NULL,
                'Thiếu nguyên liệu',
                'Nguyên liệu ' || v_ingredient.ingredient_id || ' thiếu ' || v_shortage || ' khi pha chế đơn hàng',
                'ORDER_ITEM', NEW.id
            );
        END IF;

        v_total_cost := v_total_cost + (v_ingredient.quantity * NEW.quantity) *
        (
            SELECT unit_price
            FROM ingredient_price_history
            WHERE ingredient_id = v_ingredient.ingredient_id
            ORDER BY effective_from DESC
            LIMIT 1
        );

    END LOOP;

    UPDATE order_item
    SET ingredient_cost_amount = COALESCE(v_total_cost,0)
    WHERE id = NEW.id;

    RETURN NEW;

END;
$$;

CREATE TRIGGER trg_order_item_after_insert
AFTER INSERT
ON order_item
FOR EACH ROW
EXECUTE FUNCTION fn_trg_order_item_consume_inventory();

------------------------------------------------------------
-- TRIGGER FUNCTION 2
-- AFTER UPDATE OF status ON orders
-- Ghi Timeline -> thông báo khách/kitchen/delivery -> cập
-- nhật điểm khách hàng khi hoàn tất
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_trg_order_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
BEGIN

    IF NEW.status IS DISTINCT FROM OLD.status THEN

        INSERT INTO order_timeline(order_id, from_status, to_status, action, created_by)
        VALUES(NEW.id, OLD.status, NEW.status, 'STATUS_CHANGE', NEW.created_by);

        IF NEW.status = 'CONFIRMED' THEN
            NEW.confirmed_at := NOW();
        ELSIF NEW.status = 'COMPLETED' THEN
            NEW.completed_at := NOW();
        ELSIF NEW.status = 'CANCELLED' THEN
            NEW.cancelled_at := NOW();
        END IF;

        IF NEW.customer_id IS NOT NULL THEN
            INSERT INTO notification
            (
                notification_type, channel, recipient_type, recipient_id,
                title, message, reference_type, reference_id
            )
            VALUES
            (
                'ORDER', 'PUSH', 'CUSTOMER', NEW.customer_id,
                'Cập nhật đơn hàng ' || NEW.order_code,
                'Đơn hàng của bạn hiện đang: ' || NEW.status,
                'ORDER', NEW.id
            );
        END IF;

        IF NEW.status = 'COMPLETED' AND NEW.customer_id IS NOT NULL THEN

            UPDATE customer
            SET total_order = total_order + 1,
                total_spent = total_spent + NEW.total_amount,
                loyalty_point = loyalty_point + FLOOR(NEW.total_amount / 10000)
            WHERE id = NEW.customer_id;

            INSERT INTO customer_point_history(customer_id, point, description)
            VALUES(NEW.customer_id, FLOOR(NEW.total_amount / 10000), 'Tích điểm từ đơn hàng ' || NEW.order_code);

        END IF;

    END IF;

    RETURN NEW;

END;
$$;

CREATE TRIGGER trg_order_status_change
BEFORE UPDATE
ON orders
FOR EACH ROW
EXECUTE FUNCTION fn_trg_order_status_change();

------------------------------------------------------------
-- TRIGGER FUNCTION 3
-- AFTER INSERT ON ingredient_price_history
-- Giá nguyên liệu thay đổi -> tự tính lại Cost cho toàn bộ
-- recipe_version đang active dùng nguyên liệu đó
-- (Single Source of Truth cho Cost Engine)
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_trg_ingredient_price_recalculate()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
DECLARE

    v_recipe_version RECORD;

    v_new_cost NUMERIC;

BEGIN

    FOR v_recipe_version IN
        SELECT DISTINCT rv.id
        FROM recipe_version rv
        JOIN recipe_ingredient ri ON ri.recipe_version_id = rv.id
        WHERE ri.ingredient_id = NEW.ingredient_id
          AND rv.is_current = TRUE
    LOOP

        v_new_cost := fn_calculate_recipe_cost(v_recipe_version.id);

        INSERT INTO recipe_cost(recipe_version_id, ingredient_cost, total_cost)
        VALUES(v_recipe_version.id, v_new_cost, v_new_cost)
        ON CONFLICT(recipe_version_id)
        DO UPDATE
        SET
            ingredient_cost = EXCLUDED.ingredient_cost,
            total_cost = recipe_cost.packaging_cost + recipe_cost.labor_cost + recipe_cost.overhead_cost + EXCLUDED.ingredient_cost,
            calculated_at = NOW();

    END LOOP;

    RETURN NEW;

END;
$$;

CREATE TRIGGER trg_ingredient_price_recalculate
AFTER INSERT
ON ingredient_price_history
FOR EACH ROW
EXECUTE FUNCTION fn_trg_ingredient_price_recalculate();

------------------------------------------------------------
-- TRIGGER FUNCTION 4
-- AFTER UPDATE ON inventory_stock
-- Tồn kho chạm ngưỡng tối thiểu -> cảnh báo nhập hàng
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_trg_low_stock_alert()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
DECLARE

    v_min_stock NUMERIC;

    v_ingredient_name VARCHAR;

BEGIN

    SELECT minimum_stock, ingredient_name
    INTO v_min_stock, v_ingredient_name
    FROM ingredient
    WHERE id = NEW.ingredient_id;

    IF NEW.quantity_on_hand <= v_min_stock THEN

        INSERT INTO notification
        (
            notification_type, channel, recipient_type, recipient_id,
            title, message, reference_type, reference_id
        )
        VALUES
        (
            'INVENTORY', 'IN_APP', 'STAFF', NULL,
            'Sắp hết nguyên liệu: ' || v_ingredient_name,
            'Tồn kho hiện tại: ' || NEW.quantity_on_hand || ' (định mức tối thiểu: ' || v_min_stock || ')',
            'INGREDIENT', NEW.ingredient_id
        );

    END IF;

    RETURN NEW;

END;
$$;

CREATE TRIGGER trg_inventory_low_stock
AFTER UPDATE
ON inventory_stock
FOR EACH ROW
EXECUTE FUNCTION fn_trg_low_stock_alert();

------------------------------------------------------------
-- TRIGGER FUNCTION 5
-- AFTER UPDATE OF status ON delivery
-- Đồng bộ trạng thái Đơn hàng khi Delivery hoàn tất/thất bại
-- + thông báo khách hàng
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_trg_delivery_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
DECLARE

    v_customer_id UUID;

    v_order_code VARCHAR;

BEGIN

    IF NEW.status IS DISTINCT FROM OLD.status THEN

        CASE NEW.status
            WHEN 'ASSIGNED' THEN NEW.assigned_at := NOW();
            WHEN 'PICKED_UP' THEN NEW.picked_up_at := NOW();
            WHEN 'DELIVERING' THEN NEW.delivering_at := NOW();
            WHEN 'DELIVERED' THEN NEW.delivered_at := NOW();
            ELSE NULL;
        END CASE;

        SELECT customer_id, order_code INTO v_customer_id, v_order_code
        FROM orders
        WHERE id = NEW.order_id;

        IF v_customer_id IS NOT NULL THEN
            INSERT INTO notification
            (
                notification_type, channel, recipient_type, recipient_id,
                title, message, reference_type, reference_id
            )
            VALUES
            (
                'DELIVERY', 'PUSH', 'CUSTOMER', v_customer_id,
                'Cập nhật giao hàng ' || v_order_code,
                'Trạng thái giao hàng: ' || NEW.status,
                'DELIVERY', NEW.id
            );
        END IF;

        IF NEW.status = 'DELIVERED' THEN
            UPDATE orders SET status = 'COMPLETED' WHERE id = NEW.order_id AND status <> 'COMPLETED';
        END IF;

    END IF;

    RETURN NEW;

END;
$$;

CREATE TRIGGER trg_delivery_status_change
BEFORE UPDATE
ON delivery
FOR EACH ROW
EXECUTE FUNCTION fn_trg_delivery_status_change();

/*
===========================================================
Beverage Operating System
12_view.sql
Views phục vụ Admin Dashboard / Kitchen / API Report
===========================================================
*/

------------------------------------------------------------
-- VIEW: CÔNG THỨC HIỆN HÀNH + GIÁ VỐN
------------------------------------------------------------

CREATE OR REPLACE VIEW view_current_recipe AS
SELECT
    r.id                    AS recipe_id,
    r.recipe_code,
    r.recipe_name,
    r.product_variant_id,
    rv.id                    AS recipe_version_id,
    rv.version_no,
    rc.ingredient_cost,
    rc.packaging_cost,
    rc.labor_cost,
    rc.overhead_cost,
    rc.total_cost,
    rc.calculated_at
FROM recipe r
JOIN recipe_version rv ON rv.recipe_id = r.id AND rv.is_current = TRUE
LEFT JOIN recipe_cost rc ON rc.recipe_version_id = rv.id
WHERE r.deleted_at IS NULL;

------------------------------------------------------------
-- VIEW: MENU BÁN HÀNG (SẢN PHẨM + GIÁ + GIÁ VỐN + BIÊN LỢI NHUẬN)
------------------------------------------------------------

CREATE OR REPLACE VIEW view_product_menu AS
SELECT
    p.id                    AS product_id,
    p.product_name,
    pc.category_name,
    pv.id                    AS variant_id,
    ps.size_name,
    pv.selling_price,
    COALESCE(vr.total_cost,0) AS cost_price,
    pv.selling_price - COALESCE(vr.total_cost,0) AS gross_margin,
    CASE
        WHEN pv.selling_price > 0
        THEN ROUND(((pv.selling_price - COALESCE(vr.total_cost,0)) / pv.selling_price) * 100, 2)
        ELSE 0
    END AS margin_percent,
    pv.is_active,
    p.thumbnail
FROM product p
JOIN product_category pc ON pc.id = p.category_id
JOIN product_variant pv ON pv.product_id = p.id
JOIN product_size ps ON ps.id = pv.size_id
LEFT JOIN view_current_recipe vr ON vr.product_variant_id = pv.id
WHERE p.deleted_at IS NULL;

------------------------------------------------------------
-- VIEW: TỒN KHO HIỆN TẠI (THEO NGUYÊN LIỆU)
------------------------------------------------------------

CREATE OR REPLACE VIEW view_inventory_current AS
SELECT
    i.id                    AS ingredient_id,
    i.ingredient_code,
    i.ingredient_name,
    ic.category_name,
    iu.symbol                AS unit,
    ist.warehouse_id,
    w.warehouse_name,
    COALESCE(ist.quantity_on_hand,0) AS quantity_on_hand,
    i.minimum_stock,
    i.reorder_point,
    CASE
        WHEN COALESCE(ist.quantity_on_hand,0) <= i.minimum_stock THEN TRUE
        ELSE FALSE
    END AS is_low_stock
FROM ingredient i
JOIN ingredient_category ic ON ic.id = i.category_id
JOIN ingredient_unit iu ON iu.id = i.unit_id
LEFT JOIN inventory_stock ist ON ist.ingredient_id = i.id
LEFT JOIN warehouse w ON w.id = ist.warehouse_id
WHERE i.deleted_at IS NULL;

------------------------------------------------------------
-- VIEW: NGUYÊN LIỆU SẮP HẾT
------------------------------------------------------------

CREATE OR REPLACE VIEW view_low_stock AS
SELECT *
FROM view_inventory_current
WHERE is_low_stock = TRUE;

------------------------------------------------------------
-- VIEW: LÔ HÀNG SẮP HẾT HẠN (FEFO ALERT)
------------------------------------------------------------

CREATE OR REPLACE VIEW view_expiring_batch AS
SELECT
    ib.id                    AS batch_id,
    ib.batch_code,
    i.ingredient_name,
    w.warehouse_name,
    ib.remain_quantity,
    ib.expired_at,
    (ib.expired_at::DATE - CURRENT_DATE) AS day_remaining
FROM inventory_batch ib
JOIN ingredient i ON i.id = ib.ingredient_id
JOIN warehouse w ON w.id = ib.warehouse_id
WHERE ib.remain_quantity > 0
  AND ib.expired_at IS NOT NULL
  AND ib.expired_at::DATE - CURRENT_DATE <= 7
ORDER BY ib.expired_at ASC;

------------------------------------------------------------
-- VIEW: CHI TIẾT ĐƠN HÀNG (GỘP ITEM + TOPPING + MODIFIER)
------------------------------------------------------------

CREATE OR REPLACE VIEW view_order_detail AS
SELECT
    o.id                    AS order_id,
    o.order_code,
    o.status,
    o.payment_status,
    o.order_type,
    o.total_amount,
    c.full_name              AS customer_name,
    c.phone                  AS customer_phone,
    oi.id                     AS order_item_id,
    p.product_name,
    ps.size_name,
    oi.quantity,
    oi.unit_price,
    oi.ingredient_cost_amount,
    oi.total_price,
    (
        SELECT STRING_AGG(t.topping_name, ', ')
        FROM order_item_topping oit
        JOIN topping t ON t.id = oit.topping_id
        WHERE oit.order_item_id = oi.id
    ) AS toppings,
    o.created_at
FROM orders o
JOIN order_item oi ON oi.order_id = o.id
JOIN product_variant pv ON pv.id = oi.product_variant_id
JOIN product p ON p.id = pv.product_id
JOIN product_size ps ON ps.id = pv.size_id
LEFT JOIN customer c ON c.id = o.customer_id;

------------------------------------------------------------
-- VIEW: ĐƠN HÀNG CHO MÀN HÌNH KITCHEN
------------------------------------------------------------

CREATE OR REPLACE VIEW view_kitchen_queue AS
SELECT
    o.id                    AS order_id,
    o.order_code,
    o.table_no,
    o.order_type,
    o.status,
    o.created_at,
    p.product_name,
    ps.size_name,
    oi.quantity,
    oi.note
FROM orders o
JOIN order_item oi ON oi.order_id = o.id
JOIN product_variant pv ON pv.id = oi.product_variant_id
JOIN product p ON p.id = pv.product_id
JOIN product_size ps ON ps.id = pv.size_id
WHERE o.status IN ('CONFIRMED','PREPARING')
ORDER BY o.created_at ASC;

------------------------------------------------------------
-- VIEW: TRẠNG THÁI GIAO HÀNG
------------------------------------------------------------

CREATE OR REPLACE VIEW view_delivery_status AS
SELECT
    d.id                    AS delivery_id,
    d.delivery_code,
    o.order_code,
    d.status,
    u.full_name              AS delivery_staff,
    d.receiver_name,
    d.receiver_phone,
    d.address,
    d.delivery_fee,
    d.assigned_at,
    d.delivered_at
FROM delivery d
JOIN orders o ON o.id = d.order_id
LEFT JOIN app_user u ON u.id = d.delivery_user_id;

------------------------------------------------------------
-- VIEW: DOANH THU THEO NGÀY (30 NGÀY GẦN NHẤT)
------------------------------------------------------------

CREATE OR REPLACE VIEW view_daily_revenue AS
SELECT
    summary_date,
    SUM(net_revenue)   AS net_revenue,
    SUM(total_cost)    AS total_cost,
    SUM(gross_profit)  AS gross_profit,
    SUM(total_order)   AS total_order
FROM daily_sales_summary
WHERE summary_date >= CURRENT_DATE - INTERVAL '30 day'
GROUP BY summary_date
ORDER BY summary_date DESC;

------------------------------------------------------------
-- VIEW: TOP 10 SẢN PHẨM BÁN CHẠY (30 NGÀY)
------------------------------------------------------------

CREATE OR REPLACE VIEW view_top_products AS
SELECT
    pv.id                    AS variant_id,
    p.product_name,
    ps.size_name,
    SUM(pss.quantity_sold)     AS total_quantity,
    SUM(pss.revenue)             AS total_revenue,
    SUM(pss.profit)                AS total_profit
FROM product_sales_summary pss
JOIN product_variant pv ON pv.id = pss.product_variant_id
JOIN product p ON p.id = pv.product_id
JOIN product_size ps ON ps.id = pv.size_id
WHERE pss.summary_date >= CURRENT_DATE - INTERVAL '30 day'
GROUP BY pv.id, p.product_name, ps.size_name
ORDER BY total_quantity DESC
LIMIT 10;

------------------------------------------------------------
-- VIEW: TOP 10 KHÁCH HÀNG THÂN THIẾT (30 NGÀY)
------------------------------------------------------------

CREATE OR REPLACE VIEW view_top_customers AS
SELECT
    c.id                    AS customer_id,
    c.full_name,
    c.phone,
    c.loyalty_point,
    SUM(css.order_count)       AS total_order,
    SUM(css.total_spent)         AS total_spent
FROM customer_sales_summary css
JOIN customer c ON c.id = css.customer_id
WHERE css.summary_date >= CURRENT_DATE - INTERVAL '30 day'
GROUP BY c.id, c.full_name, c.phone, c.loyalty_point
ORDER BY total_spent DESC
LIMIT 10;

/*
===========================================================
Beverage Operating System
13_seed.sql
Seed Data (Master Data + 1 sản phẩm demo "Matcha Latte"
theo đúng ví dụ trong tài liệu ý tưởng: Recipe First)

Toàn bộ script dùng ON CONFLICT DO NOTHING theo mã (code) tự
nhiên + subquery tra cứu id -> chạy lại nhiều lần an toàn
(idempotent), không phá dữ liệu đã có.
===========================================================
*/

------------------------------------------------------------
-- 1. ROLE & PERMISSION
------------------------------------------------------------

INSERT INTO role(code, name, description)
VALUES
('OWNER','Chủ quán','Toàn quyền hệ thống'),
('MANAGER','Quản lý','Quản lý vận hành, không có quyền hệ thống'),
('KITCHEN','Pha chế','Màn hình Kitchen'),
('DELIVERY','Giao hàng','Màn hình Delivery'),
('CUSTOMER','Khách hàng','Tài khoản khách hàng trên Website')
ON CONFLICT (code) DO NOTHING;

INSERT INTO permission(code, module, action, description)
VALUES
('order.view','ORDER','VIEW','Xem đơn hàng'),
('order.manage','ORDER','MANAGE','Quản lý đơn hàng'),
('inventory.view','INVENTORY','VIEW','Xem tồn kho'),
('inventory.manage','INVENTORY','MANAGE','Quản lý tồn kho'),
('report.view','REPORT','VIEW','Xem báo cáo'),
('system.manage','SYSTEM','MANAGE','Quản trị hệ thống')
ON CONFLICT (code) DO NOTHING;

INSERT INTO role_permission(role_id, permission_id)
SELECT r.id, p.id
FROM role r
CROSS JOIN permission p
WHERE r.code = 'OWNER'
ON CONFLICT DO NOTHING;

INSERT INTO role_permission(role_id, permission_id)
SELECT r.id, p.id
FROM role r
JOIN permission p ON p.code IN ('order.view','order.manage','inventory.view','report.view')
WHERE r.code = 'MANAGER'
ON CONFLICT DO NOTHING;

INSERT INTO role_permission(role_id, permission_id)
SELECT r.id, p.id
FROM role r
JOIN permission p ON p.code = 'order.view'
WHERE r.code IN ('KITCHEN','DELIVERY')
ON CONFLICT DO NOTHING;

------------------------------------------------------------
-- 2. APP USER (OWNER MẶC ĐỊNH)
-- password mặc định "Admin@123" -> cần đổi ngay sau khi cài đặt
------------------------------------------------------------

INSERT INTO app_user(username, email, phone, password_hash, full_name, status, email_verified)
VALUES
('owner','owner@bos.local','0900000000', crypt('Admin@123', gen_salt('bf')), 'Chủ quán', 'ACTIVE', TRUE)
ON CONFLICT (username) DO NOTHING;

INSERT INTO user_role(user_id, role_id)
SELECT u.id, r.id
FROM app_user u
JOIN role r ON r.code = 'OWNER'
WHERE u.username = 'owner'
ON CONFLICT DO NOTHING;

------------------------------------------------------------
-- 3. APP SETTING
------------------------------------------------------------

INSERT INTO app_setting(setting_key, setting_value, description)
VALUES
('shop.name','BOS Beverage','Tên quán hiển thị trên Website/Hoá đơn'),
('shop.tax_percent','0','Thuế VAT áp dụng (%)'),
('loyalty.point_per_vnd','10000','Số VND tương ứng 1 điểm tích luỹ'),
('order.code_prefix','ORD','Tiền tố mã đơn hàng')
ON CONFLICT (setting_key) DO NOTHING;

------------------------------------------------------------
-- 4. WAREHOUSE (KHO CHÍNH)
------------------------------------------------------------

INSERT INTO warehouse(warehouse_code, warehouse_name, address, is_default)
VALUES
('WH-MAIN','Kho chính','Chi nhánh 1', TRUE)
ON CONFLICT (warehouse_code) DO NOTHING;

------------------------------------------------------------
-- 5. SUPPLIER
------------------------------------------------------------

INSERT INTO supplier(supplier_code, supplier_name, phone, email, address)
VALUES
('SUP-001','Công ty Nguyên liệu Pha chế ABC','0909123456','contact@abc-supply.vn','TP. Hồ Chí Minh')
ON CONFLICT (supplier_code) DO NOTHING;

------------------------------------------------------------
-- 6. PRODUCT CATEGORY
------------------------------------------------------------

INSERT INTO product_category(category_code, category_name, slug, display_order)
VALUES
('COFFEE','Coffee','coffee',1),
('TEA','Tea','tea',2),
('MILK_TEA','Milk Tea','milk-tea',3),
('FRUIT_TEA','Fruit Tea','fruit-tea',4),
('MATCHA','Matcha','matcha',5),
('TOPPING','Topping','topping',6)
ON CONFLICT (category_code) DO NOTHING;

------------------------------------------------------------
-- 7. PRODUCT SIZE
------------------------------------------------------------

INSERT INTO product_size(size_code, size_name, display_order)
VALUES
('S','Size S',1),
('M','Size M',2),
('L','Size L',3)
ON CONFLICT (size_code) DO NOTHING;

------------------------------------------------------------
-- 8. INGREDIENT CATEGORY
------------------------------------------------------------

INSERT INTO ingredient_category(category_code, category_name, display_order)
VALUES
('DAIRY','Sữa & Kem',1),
('TEA_POWDER','Trà & Bột',2),
('SYRUP','Đường & Syrup',3),
('PACKAGING','Bao bì',4),
('TOPPING_ING','Nguyên liệu Topping',5)
ON CONFLICT (category_code) DO NOTHING;

------------------------------------------------------------
-- 9. INGREDIENT
-- Theo đúng ví dụ trong ý tưởng: Matcha, Milk, Sugar, Ice,
-- Cup, Lid, Straw, Sticker - mọi thứ đều là Ingredient
------------------------------------------------------------

INSERT INTO ingredient(category_id, ingredient_code, ingredient_name, unit_id, minimum_stock, reorder_point, is_inventory)
SELECT ic.id, v.code, v.name, iu.id, v.min_stock, v.reorder, TRUE
FROM
(
    VALUES
    ('ING-MATCHA','Matcha','TEA_POWDER','G',500,1000),
    ('ING-MILK','Milk','DAIRY','ML',5000,10000),
    ('ING-SUGAR','Sugar','SYRUP','ML',3000,6000),
    ('ING-ICE','Ice','DAIRY','G',10000,20000),
    ('ING-CUP','Cup','PACKAGING','PCS',200,500),
    ('ING-LID','Lid','PACKAGING','PCS',200,500),
    ('ING-STRAW','Straw','PACKAGING','PCS',200,500),
    ('ING-STICKER','Sticker','PACKAGING','PCS',200,500)
) AS v(code, name, cat_code, unit_code, min_stock, reorder)
JOIN ingredient_category ic ON ic.category_code = v.cat_code
JOIN ingredient_unit iu ON iu.unit_code = v.unit_code
ON CONFLICT (ingredient_code) DO NOTHING;

------------------------------------------------------------
-- 10. GIÁ NGUYÊN LIỆU BAN ĐẦU
-- (INSERT trực tiếp thay vì qua fn_import_stock để không sinh
-- batch/stock ảo; kho thực tế sẽ vào qua 07_purchase.sql)
------------------------------------------------------------

INSERT INTO ingredient_price_history(ingredient_id, supplier_id, unit_price, note)
SELECT i.id, s.id, v.price, 'Giá khởi tạo ban đầu'
FROM
(
    VALUES
    ('ING-MATCHA', 800),
    ('ING-MILK', 25),
    ('ING-SUGAR', 15),
    ('ING-ICE', 3),
    ('ING-CUP', 800),
    ('ING-LID', 300),
    ('ING-STRAW', 150),
    ('ING-STICKER', 100)
) AS v(code, price)
JOIN ingredient i ON i.ingredient_code = v.code
CROSS JOIN (SELECT id FROM supplier WHERE supplier_code = 'SUP-001') s
WHERE NOT EXISTS
(
    SELECT 1 FROM ingredient_price_history iph WHERE iph.ingredient_id = i.id
);

------------------------------------------------------------
-- 11. SẢN PHẨM DEMO: MATCHA LATTE (Size M)
------------------------------------------------------------

INSERT INTO product(category_id, product_code, product_name, slug, short_description, is_active)
SELECT pc.id, 'PRD-MATCHA-LATTE', 'Matcha Latte', 'matcha-latte', 'Trà xanh Nhật Bản hoà cùng sữa tươi', TRUE
FROM product_category pc
WHERE pc.category_code = 'MATCHA'
ON CONFLICT (product_code) DO NOTHING;

INSERT INTO product_variant(product_id, size_id, sku, selling_price, is_default)
SELECT p.id, ps.id, 'SKU-MATCHA-LATTE-M', 45000, TRUE
FROM product p
JOIN product_size ps ON ps.size_code = 'M'
WHERE p.product_code = 'PRD-MATCHA-LATTE'
ON CONFLICT (sku) DO NOTHING;

------------------------------------------------------------
-- 12. RECIPE - MATCHA LATTE
-- Matcha 5g / Milk 120ml / Sugar 20ml / Cup 1 / Lid 1
------------------------------------------------------------

INSERT INTO recipe(recipe_code, recipe_name, product_variant_id)
SELECT 'RCP-MATCHA-LATTE-M', 'Công thức Matcha Latte (M)', pv.id
FROM product_variant pv
WHERE pv.sku = 'SKU-MATCHA-LATTE-M'
ON CONFLICT (recipe_code) DO NOTHING;

INSERT INTO recipe_version(recipe_id, version_no, version_name, is_current, approved_at)
SELECT r.id, 1, 'Phiên bản đầu tiên', TRUE, NOW()
FROM recipe r
WHERE r.recipe_code = 'RCP-MATCHA-LATTE-M'
ON CONFLICT (recipe_id, version_no) DO NOTHING;

INSERT INTO recipe_ingredient(recipe_version_id, ingredient_id, unit_id, quantity, display_order)
SELECT rv.id, i.id, iu.id, v.quantity, v.ord
FROM
(
    VALUES
    ('ING-MATCHA','G',5,1),
    ('ING-MILK','ML',120,2),
    ('ING-SUGAR','ML',20,3),
    ('ING-CUP','PCS',1,4),
    ('ING-LID','PCS',1,5)
) AS v(ing_code, unit_code, quantity, ord)
JOIN ingredient i ON i.ingredient_code = v.ing_code
JOIN ingredient_unit iu ON iu.unit_code = v.unit_code
CROSS JOIN
(
    SELECT rv.id
    FROM recipe_version rv
    JOIN recipe r ON r.id = rv.recipe_id
    WHERE r.recipe_code = 'RCP-MATCHA-LATTE-M' AND rv.is_current = TRUE
) rv
WHERE NOT EXISTS
(
    SELECT 1 FROM recipe_ingredient ri WHERE ri.recipe_version_id = rv.id AND ri.ingredient_id = i.id
);

INSERT INTO recipe_step(recipe_version_id, step_no, step_name, instruction, estimated_second)
SELECT rv.id, v.step_no, v.step_name, v.instruction, v.second
FROM
(
    VALUES
    (1,'Pha matcha','Đánh tan bột matcha với 30ml nước nóng cho tan hoàn toàn',60),
    (2,'Pha chế','Thêm đá, sữa tươi và đường vào ly, khuấy đều',60),
    (3,'Hoàn thiện','Đổ matcha đã đánh lên trên cùng, đậy nắp, dán sticker',30)
) AS v(step_no, step_name, instruction, second)
CROSS JOIN
(
    SELECT rv.id
    FROM recipe_version rv
    JOIN recipe r ON r.id = rv.recipe_id
    WHERE r.recipe_code = 'RCP-MATCHA-LATTE-M' AND rv.is_current = TRUE
) rv
WHERE NOT EXISTS
(
    SELECT 1 FROM recipe_step rs WHERE rs.recipe_version_id = rv.id AND rs.step_no = v.step_no
);

------------------------------------------------------------
-- 13. TÍNH GIÁ VỐN BAN ĐẦU CHO CÔNG THỨC DEMO
------------------------------------------------------------

INSERT INTO recipe_cost(recipe_version_id, ingredient_cost, total_cost)
SELECT rv.id, fn_calculate_recipe_cost(rv.id), fn_calculate_recipe_cost(rv.id)
FROM recipe_version rv
JOIN recipe r ON r.id = rv.recipe_id
WHERE r.recipe_code = 'RCP-MATCHA-LATTE-M' AND rv.is_current = TRUE
ON CONFLICT (recipe_version_id) DO NOTHING;

------------------------------------------------------------
-- 14. KHÁCH HÀNG DEMO
------------------------------------------------------------

INSERT INTO customer(customer_code, full_name, phone, gender)
VALUES
('CUS-000001','Nguyễn Văn A','0912345678','MALE')
ON CONFLICT (customer_code) DO NOTHING;

/*
===========================================================
Beverage Operating System
14_promotion.sql
Voucher / Promotion (mảnh còn thiếu của CRM theo ý_tưởng.txt:
"Khách hàng. Lịch sử. Voucher. Điểm.")

Phạm vi MVP - cố tình giữ gọn:
 - 1 voucher áp dụng ở cấp ĐƠN HÀNG (không áp theo từng item)
 - Không làm hệ thống rule engine phức tạp nhiều tầng, dùng
   JSONB cho promotion để linh hoạt mà không sinh thêm chục bảng
 - Tận dụng lại customer.loyalty_point đã có sẵn từ 11_trigger.sql,
   KHÔNG tạo thêm hệ thống hạng thành viên (tier) vì chưa có yêu
   cầu cụ thể - tránh over-engineering

Không đụng tới bảng đã có (orders, order_item...) bằng ALTER,
mà tạo bảng liên kết order_voucher riêng -> an toàn, không phá
vỡ 08_order.sql.
===========================================================
*/

------------------------------------------------------------
-- ENUM
------------------------------------------------------------

CREATE TYPE voucher_type AS ENUM
(
    'PERCENT',
    'FIXED_AMOUNT',
    'FREE_SHIPPING'
);

CREATE TYPE voucher_status AS ENUM
(
    'ACTIVE',
    'INACTIVE',
    'EXPIRED'
);

CREATE TYPE promotion_type AS ENUM
(
    'BUY_X_GET_Y',
    'COMBO_DISCOUNT',
    'HAPPY_HOUR',
    'FLASH_SALE'
);

------------------------------------------------------------
-- VOUCHER
------------------------------------------------------------

CREATE TABLE voucher
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    voucher_code              VARCHAR(50) NOT NULL,

    voucher_name                 VARCHAR(255) NOT NULL,

    description                     TEXT,

    voucher_type                      voucher_type NOT NULL,

    discount_percent                     NUMERIC(5,2),

    discount_amount                        NUMERIC(18,2),

    max_discount_amount                       NUMERIC(18,2),

    min_order_amount                            NUMERIC(18,2) DEFAULT 0,

    usage_limit_total                             INT,

    usage_limit_per_customer                        INT DEFAULT 1,

    used_count                                        INT DEFAULT 0,

    start_date                                          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    end_date                                              TIMESTAMPTZ,

    status                                                  voucher_status DEFAULT 'ACTIVE',

    created_by                                                UUID,

    created_at                                                  TIMESTAMPTZ DEFAULT NOW(),

    updated_at                                                    TIMESTAMPTZ DEFAULT NOW(),

    deleted_at                                                      TIMESTAMPTZ,

    version                                                           INT DEFAULT 1,

    CONSTRAINT fk_voucher_user
        FOREIGN KEY(created_by)
        REFERENCES app_user(id),

    CONSTRAINT chk_voucher_percent
        CHECK(voucher_type <> 'PERCENT' OR (discount_percent > 0 AND discount_percent <= 100)),

    CONSTRAINT chk_voucher_fixed
        CHECK(voucher_type <> 'FIXED_AMOUNT' OR discount_amount > 0),

    CONSTRAINT chk_voucher_min_order
        CHECK(min_order_amount >= 0),

    CONSTRAINT chk_voucher_usage_limit
        CHECK(usage_limit_total IS NULL OR usage_limit_total > 0),

    CONSTRAINT chk_voucher_date_range
        CHECK(end_date IS NULL OR end_date > start_date)
);

-- Mã voucher chỉ cần UNIQUE trong số các voucher còn sống, để
-- có thể tái sử dụng mã cũ sau khi voucher hết hạn bị xoá mềm
-- (cùng cách tiếp cận như 15_hotfix.sql xử lý cho product/customer)

CREATE UNIQUE INDEX uq_voucher_code_active
ON voucher(voucher_code)
WHERE deleted_at IS NULL;

CREATE INDEX idx_voucher_status
ON voucher(status);

CREATE INDEX idx_voucher_date_range
ON voucher(start_date, end_date);

------------------------------------------------------------
-- VOUCHER SCOPE (tuỳ chọn giới hạn theo sản phẩm/danh mục)
-- Không có dòng nào -> áp dụng cho toàn bộ menu
------------------------------------------------------------

CREATE TABLE voucher_product
(
    voucher_id          UUID,

    product_id           UUID,

    PRIMARY KEY(voucher_id, product_id),

    CONSTRAINT fk_voucher_product_voucher
        FOREIGN KEY(voucher_id)
        REFERENCES voucher(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_voucher_product_product
        FOREIGN KEY(product_id)
        REFERENCES product(id)
        ON DELETE CASCADE
);

CREATE TABLE voucher_category
(
    voucher_id          UUID,

    category_id           UUID,

    PRIMARY KEY(voucher_id, category_id),

    CONSTRAINT fk_voucher_category_voucher
        FOREIGN KEY(voucher_id)
        REFERENCES voucher(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_voucher_category_category
        FOREIGN KEY(category_id)
        REFERENCES product_category(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- CUSTOMER VOUCHER (VOUCHER PHÁT RIÊNG CHO 1 KHÁCH - VD SINH NHẬT)
------------------------------------------------------------

CREATE TABLE customer_voucher
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    customer_id               UUID NOT NULL,

    voucher_id                   UUID NOT NULL,

    assigned_at                     TIMESTAMPTZ DEFAULT NOW(),

    is_used                            BOOLEAN DEFAULT FALSE,

    used_at                               TIMESTAMPTZ,

    CONSTRAINT fk_customer_voucher_customer
        FOREIGN KEY(customer_id)
        REFERENCES customer(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_customer_voucher_voucher
        FOREIGN KEY(voucher_id)
        REFERENCES voucher(id)
        ON DELETE CASCADE,

    CONSTRAINT uq_customer_voucher
        UNIQUE(customer_id, voucher_id)
);

CREATE INDEX idx_customer_voucher_customer
ON customer_voucher(customer_id);

------------------------------------------------------------
-- ORDER VOUCHER (VOUCHER ĐÃ ÁP DỤNG CHO 1 ĐƠN HÀNG CỤ THỂ)
------------------------------------------------------------

CREATE TABLE order_voucher
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    order_id                  UUID NOT NULL,

    voucher_id                   UUID NOT NULL,

    discount_amount                 NUMERIC(18,2) NOT NULL,

    created_at                        TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_order_voucher_order
        FOREIGN KEY(order_id)
        REFERENCES orders(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_order_voucher_voucher
        FOREIGN KEY(voucher_id)
        REFERENCES voucher(id),

    CONSTRAINT uq_order_voucher
        UNIQUE(order_id, voucher_id)
);

CREATE INDEX idx_order_voucher_order
ON order_voucher(order_id);

CREATE INDEX idx_order_voucher_voucher
ON order_voucher(voucher_id);

------------------------------------------------------------
-- PROMOTION (CHIẾN DỊCH LINH HOẠT - HAPPY HOUR / FLASH SALE...)
-- Dùng JSONB cho điều kiện để không phải sinh thêm nhiều bảng
-- con cho từng loại khuyến mãi ở giai đoạn MVP. Khi nghiệp vụ
-- rõ ràng và ổn định hơn, có thể tách JSONB này ra bảng riêng.
------------------------------------------------------------

CREATE TABLE promotion
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    promotion_code            VARCHAR(50) NOT NULL,

    promotion_name               VARCHAR(255) NOT NULL,

    promotion_type                  promotion_type NOT NULL,

    description                        TEXT,

    conditions                           JSONB,

    start_date                             TIMESTAMPTZ NOT NULL,

    end_date                                 TIMESTAMPTZ,

    is_active                                  BOOLEAN DEFAULT TRUE,

    created_by                                   UUID,

    created_at                                     TIMESTAMPTZ DEFAULT NOW(),

    updated_at                                       TIMESTAMPTZ DEFAULT NOW(),

    version                                            INT DEFAULT 1,

    CONSTRAINT fk_promotion_user
        FOREIGN KEY(created_by)
        REFERENCES app_user(id),

    CONSTRAINT chk_promotion_date_range
        CHECK(end_date IS NULL OR end_date > start_date)
);

CREATE UNIQUE INDEX uq_promotion_code_active
ON promotion(promotion_code)
WHERE is_active = TRUE;

CREATE INDEX idx_promotion_date_range
ON promotion(start_date, end_date);

------------------------------------------------------------
-- FUNCTION: KIỂM TRA VOUCHER CÓ HỢP LỆ KHÔNG
-- Backend gọi hàm này TRƯỚC khi cho khách bấm "Áp dụng" để
-- hiển thị lỗi ngay trên UI, KHÔNG tự trừ lượt dùng ở bước này
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_validate_voucher
(
    p_voucher_code VARCHAR,
    p_customer_id UUID,
    p_order_amount NUMERIC
)
RETURNS TABLE
(
    is_valid BOOLEAN,
    voucher_id UUID,
    discount_amount NUMERIC,
    message TEXT
)
LANGUAGE plpgsql
AS
$$
DECLARE

    v_voucher RECORD;

    v_used_by_customer INT;

    v_discount NUMERIC := 0;

BEGIN

    SELECT * INTO v_voucher
    FROM voucher
    WHERE voucher_code = p_voucher_code
      AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, NULL::UUID, 0::NUMERIC, 'Mã voucher không tồn tại';
        RETURN;
    END IF;

    IF v_voucher.status <> 'ACTIVE' THEN
        RETURN QUERY SELECT FALSE, v_voucher.id, 0::NUMERIC, 'Voucher đã ngừng áp dụng';
        RETURN;
    END IF;

    IF NOW() < v_voucher.start_date OR (v_voucher.end_date IS NOT NULL AND NOW() > v_voucher.end_date) THEN
        RETURN QUERY SELECT FALSE, v_voucher.id, 0::NUMERIC, 'Voucher chưa tới hạn hoặc đã hết hạn';
        RETURN;
    END IF;

    IF p_order_amount < v_voucher.min_order_amount THEN
        RETURN QUERY SELECT FALSE, v_voucher.id, 0::NUMERIC,
            'Đơn hàng chưa đạt giá trị tối thiểu ' || v_voucher.min_order_amount;
        RETURN;
    END IF;

    IF v_voucher.usage_limit_total IS NOT NULL AND v_voucher.used_count >= v_voucher.usage_limit_total THEN
        RETURN QUERY SELECT FALSE, v_voucher.id, 0::NUMERIC, 'Voucher đã hết lượt sử dụng';
        RETURN;
    END IF;

    IF p_customer_id IS NOT NULL THEN

        SELECT COUNT(*) INTO v_used_by_customer
        FROM order_voucher ov
        JOIN orders o ON o.id = ov.order_id
        WHERE ov.voucher_id = v_voucher.id
          AND o.customer_id = p_customer_id
          AND o.status <> 'CANCELLED';

        IF v_used_by_customer >= v_voucher.usage_limit_per_customer THEN
            RETURN QUERY SELECT FALSE, v_voucher.id, 0::NUMERIC, 'Bạn đã dùng hết lượt cho voucher này';
            RETURN;
        END IF;

    END IF;

    -- Tính số tiền giảm
    IF v_voucher.voucher_type = 'PERCENT' THEN
        v_discount := p_order_amount * v_voucher.discount_percent / 100;
        IF v_voucher.max_discount_amount IS NOT NULL THEN
            v_discount := LEAST(v_discount, v_voucher.max_discount_amount);
        END IF;
    ELSIF v_voucher.voucher_type = 'FIXED_AMOUNT' THEN
        v_discount := LEAST(v_voucher.discount_amount, p_order_amount);
    ELSE
        v_discount := 0; -- FREE_SHIPPING xử lý riêng ở shipping_fee, không trừ vào subtotal
    END IF;

    RETURN QUERY SELECT TRUE, v_voucher.id, v_discount, 'OK';

END;
$$;

------------------------------------------------------------
-- FUNCTION: ÁP DỤNG VOUCHER VÀO ĐƠN HÀNG
-- Khoá dòng voucher (FOR UPDATE) để tránh 2 khách cùng dùng nốt
-- lượt cuối cùng của voucher tại cùng 1 thời điểm (race condition)
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_apply_voucher
(
    p_order_id UUID,
    p_voucher_code VARCHAR,
    p_customer_id UUID
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS
$$
DECLARE

    v_voucher_id UUID;

    v_voucher_row RECORD;

    v_order_amount NUMERIC;

    v_check RECORD;

BEGIN

    SELECT COALESCE(SUM(total_price),0) INTO v_order_amount
    FROM order_item
    WHERE order_id = p_order_id;

    SELECT * INTO v_check
    FROM fn_validate_voucher(p_voucher_code, p_customer_id, v_order_amount);

    IF NOT v_check.is_valid THEN
        RAISE EXCEPTION '%', v_check.message;
    END IF;

    -- Khoá dòng voucher để cập nhật used_count an toàn khi nhiều
    -- người cùng áp dụng đồng thời
    SELECT * INTO v_voucher_row
    FROM voucher
    WHERE id = v_check.voucher_id
    FOR UPDATE;

    IF v_voucher_row.usage_limit_total IS NOT NULL AND v_voucher_row.used_count >= v_voucher_row.usage_limit_total THEN
        RAISE EXCEPTION 'Voucher đã hết lượt sử dụng (trùng lúc với người khác)';
    END IF;

    INSERT INTO order_voucher(order_id, voucher_id, discount_amount)
    VALUES(p_order_id, v_check.voucher_id, v_check.discount_amount)
    ON CONFLICT(order_id, voucher_id) DO NOTHING;

    UPDATE voucher
    SET used_count = used_count + 1
    WHERE id = v_check.voucher_id;

    IF p_customer_id IS NOT NULL THEN
        UPDATE customer_voucher
        SET is_used = TRUE, used_at = NOW()
        WHERE customer_id = p_customer_id AND voucher_id = v_check.voucher_id;
    END IF;

    UPDATE orders
    SET discount_amount = COALESCE(discount_amount,0) + v_check.discount_amount,
        total_amount = subtotal_amount + shipping_fee + tax_amount - (COALESCE(discount_amount,0) + v_check.discount_amount)
    WHERE id = p_order_id;

    RETURN v_check.discount_amount;

END;
$$;

------------------------------------------------------------
-- UPDATE TRIGGER
------------------------------------------------------------

CREATE TRIGGER trg_voucher_update
BEFORE UPDATE
ON voucher
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_promotion_update
BEFORE UPDATE
ON promotion
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

/*
===========================================================
Beverage Operating System
15_hotfix.sql
Patch trước khi code Backend (5 điểm, KHÔNG mở rộng thêm)

Phạm vi CHỈ gồm:
 1. Unique 1 recipe chỉ có 1 version đang active
 2. Chặn recipe_ingredient.quantity <= 0
 3. Chặn selling_price âm (product_variant / topping / combo)
 4. Đồng bộ soft-delete (deleted_at) cho 5 bảng chính
 5. Index cho bảng orders

Lưu ý: Voucher/CRM đã được tách ra thành module riêng ở
14_promotion.sql (chạy trước file này), nên KHÔNG lặp lại ở
đây. File này vẫn cố tình KHÔNG đụng tới: hoàn kho khi hủy
đơn, wiring price_list vào Order, Branch/Store, Cart... để
lại cho sau, tránh over-engineering ở giai đoạn MVP.

Script idempotent - chạy lại nhiều lần không lỗi, an toàn áp
lên DB đã có dữ liệu thật (dùng ADD CONSTRAINT ... NOT VALID
+ VALIDATE CONSTRAINT để tránh khoá bảng lâu khi bảng đã lớn).
===========================================================
*/

------------------------------------------------------------
-- 1. UNIQUE: 1 RECIPE CHỈ CÓ 1 VERSION is_current = TRUE
------------------------------------------------------------

-- Dọn dữ liệu cũ trước (nếu lỡ có 2 version cùng active do thao
-- tác thủ công) để tránh ALTER/CREATE INDEX phía dưới bị lỗi.
-- Quy tắc giữ lại: version có effective_from mới nhất, hoà thì
-- lấy version_no lớn nhất.

WITH ranked AS
(
    SELECT
        id,
        ROW_NUMBER() OVER
        (
            PARTITION BY recipe_id
            ORDER BY effective_from DESC, version_no DESC
        ) AS rn
    FROM recipe_version
    WHERE is_current = TRUE
)
UPDATE recipe_version rv
SET is_current = FALSE
FROM ranked
WHERE rv.id = ranked.id
  AND ranked.rn > 1;

CREATE UNIQUE INDEX IF NOT EXISTS uq_recipe_current
ON recipe_version(recipe_id)
WHERE is_current = TRUE;

------------------------------------------------------------
-- 2. CHẶN SỐ LƯỢNG NGUYÊN LIỆU <= 0 TRONG CÔNG THỨC
------------------------------------------------------------

ALTER TABLE recipe_ingredient
ADD CONSTRAINT chk_recipe_ingredient_qty
CHECK(quantity > 0)
NOT VALID;

ALTER TABLE recipe_ingredient
VALIDATE CONSTRAINT chk_recipe_ingredient_qty;

------------------------------------------------------------
-- 3. CHẶN GIÁ BÁN ÂM
------------------------------------------------------------

ALTER TABLE product_variant
ADD CONSTRAINT chk_product_variant_price
CHECK(selling_price >= 0)
NOT VALID;

ALTER TABLE product_variant
VALIDATE CONSTRAINT chk_product_variant_price;

ALTER TABLE topping
ADD CONSTRAINT chk_topping_price
CHECK(selling_price >= 0)
NOT VALID;

ALTER TABLE topping
VALIDATE CONSTRAINT chk_topping_price;

ALTER TABLE combo
ADD CONSTRAINT chk_combo_price
CHECK(selling_price >= 0)
NOT VALID;

ALTER TABLE combo
VALIDATE CONSTRAINT chk_combo_price;

------------------------------------------------------------
-- 4. ĐỒNG BỘ SOFT DELETE (deleted_at) CHO 5 BẢNG CHÍNH
--
-- Đã kiểm tra thực tế trên schema hiện tại: product, ingredient,
-- customer, supplier ĐÃ có deleted_at sẵn từ 03/04/05/07. Chỉ
-- riêng product_variant là thiếu. Dùng ADD COLUMN IF NOT EXISTS
-- cho cả 5 bảng để script này an toàn dù chạy trên schema nào.
------------------------------------------------------------

ALTER TABLE product         ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE product_variant ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE ingredient      ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE customer        ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE supplier        ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- Hệ quả đi kèm bắt buộc phải xử lý: các cột mã (product_code,
-- sku, ingredient_code, customer_code, supplier_code) đang là
-- UNIQUE toàn bảng. Nếu chỉ thêm deleted_at mà không đổi ràng
-- buộc này, sau khi "xoá mềm" 1 sản phẩm sẽ KHÔNG THỂ tạo mới
-- sản phẩm khác dùng lại đúng mã đó -> đổi thành UNIQUE INDEX
-- có điều kiện (chỉ áp dụng cho bản ghi còn sống).

ALTER TABLE product
DROP CONSTRAINT IF EXISTS product_product_code_key;

CREATE UNIQUE INDEX IF NOT EXISTS uq_product_code_active
ON product(product_code)
WHERE deleted_at IS NULL;

ALTER TABLE product_variant
DROP CONSTRAINT IF EXISTS product_variant_sku_key;

CREATE UNIQUE INDEX IF NOT EXISTS uq_product_variant_sku_active
ON product_variant(sku)
WHERE deleted_at IS NULL AND sku IS NOT NULL;

ALTER TABLE ingredient
DROP CONSTRAINT IF EXISTS ingredient_ingredient_code_key;

CREATE UNIQUE INDEX IF NOT EXISTS uq_ingredient_code_active
ON ingredient(ingredient_code)
WHERE deleted_at IS NULL;

ALTER TABLE customer
DROP CONSTRAINT IF EXISTS customer_customer_code_key;

CREATE UNIQUE INDEX IF NOT EXISTS uq_customer_code_active
ON customer(customer_code)
WHERE deleted_at IS NULL;

ALTER TABLE supplier
DROP CONSTRAINT IF EXISTS supplier_supplier_code_key;

CREATE UNIQUE INDEX IF NOT EXISTS uq_supplier_code_active
ON supplier(supplier_code)
WHERE deleted_at IS NULL;

------------------------------------------------------------
-- 5. INDEX CHO ORDER
--
-- Lưu ý đặt tên: bảng đơn hàng trong hệ thống này tên là
-- "orders" (không phải "customer_order"), cột trạng thái tên
-- là "status" (không phải "order_status" - "order_status" là
-- tên KIỂU ENUM dùng cho cột status, không phải tên cột).
-- 3 index dưới đây thực chất ĐÃ được tạo sẵn trong 08_order.sql
-- (idx_order_customer, idx_order_status, idx_order_created).
-- Dùng IF NOT EXISTS để script này chạy an toàn dù index đã có,
-- không tạo trùng, không báo lỗi.
------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_order_customer ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_order_status   ON orders(status);
CREATE INDEX IF NOT EXISTS idx_order_created  ON orders(created_at);